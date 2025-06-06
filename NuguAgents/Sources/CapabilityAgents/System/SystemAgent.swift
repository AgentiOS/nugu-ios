//
//  SystemAgent.swift
//  NuguAgents
//
//  Created by yonghoonKwon on 24/05/2019.
//  Copyright (c) 2019 SK Telecom Co., Ltd. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

import NuguCore
import NuguUtils

import RxSwift

public final class SystemAgent: SystemAgentProtocol {
    // CapabilityAgentable
    public var capabilityAgentProperty: CapabilityAgentProperty = CapabilityAgentProperty(category: .system, version: "1.4")
    
    // Private
    private let contextManager: ContextManageable
    private let streamDataRouter: StreamDataRoutable
    private let directiveSequencer: DirectiveSequenceable
    private let systemDispatchQueue = DispatchQueue(label: "com.sktelecom.romaine.system_agent", qos: .userInitiated)
    
    // Handleable Directive
    private lazy var handleableDirectiveInfos = [
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "HandoffConnection", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleHandOffConnection),
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "UpdateState", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleUpdateState),
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "Exception", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleException),
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "Revoke", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleRevoke),
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "NoDirectives", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleNoDirectives),
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "Noop", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: { { $1(.finished) } }),
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "ResetConnection", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleResetConnection),
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "TerminateApp", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleTerminateApp),
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "RequireUpdate", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleRequireUpdate)
    ]
    
    private var disposeBag = DisposeBag()
    
    public init(
        contextManager: ContextManageable,
        streamDataRouter: StreamDataRoutable,
        directiveSequencer: DirectiveSequenceable
    ) {
        self.contextManager = contextManager
        self.streamDataRouter = streamDataRouter
        self.directiveSequencer = directiveSequencer
        
        contextManager.addProvider(contextInfoProvider)
        directiveSequencer.add(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
    }
    
    deinit {
        contextManager.removeProvider(contextInfoProvider)
        directiveSequencer.remove(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
    }
    
    public lazy var contextInfoProvider: ContextInfoProviderType = { [weak self] completion in
        guard let self = self else { return }
        
        let payload: [String: AnyHashable] = [
            "version": self.capabilityAgentProperty.version
        ]
        completion(ContextInfo(contextType: .capability, name: self.capabilityAgentProperty.name, payload: payload))
    }
}

// MARK: - Private (handle directive)

private extension SystemAgent {
    func handleHandOffConnection() -> HandleDirective {
        return { [weak self] directive, completion in
            guard let serverPolicy = try? JSONDecoder().decode(Policy.ServerPolicy.self, from: directive.payload) else {
                completion(.failed("Invalid payload"))
                return
            }
            defer { completion(.finished) }

            self?.systemDispatchQueue.async { [weak self] in
                log.info("try to handoff policy: \(serverPolicy)")
                self?.streamDataRouter.startReceiveServerInitiatedDirective(to: serverPolicy)
            }
        }
    }
    
    func handleUpdateState() -> HandleDirective {
        return { [weak self] directive, completion in
            defer { completion(.finished) }
            
            self?.sendFullContextEvent(Event(
                typeInfo: .synchronizeState,
                referrerDialogRequestId: directive.header.dialogRequestId
            ).rx)
        }
    }
    
    func handleException() -> HandleDirective {
        return { [weak self] directive, completion in
            guard let exceptionItem = try? JSONDecoder().decode(SystemAgentExceptionItem.self, from: directive.payload) else {
                completion(.failed("Invalid payload"))
                return
            }
            defer { completion(.finished) }

            self?.systemDispatchQueue.async { [weak self] in
                switch exceptionItem.code {
                case .fail(let code):
                    self?.post(NuguAgentNotification.System.Exception(code: code, header: directive.header))
                case .warning(let code):
                    self?.post(NuguAgentNotification.System.ExceptionWarning(code: code, header: directive.header))
                }
            }
        }
    }
    
    func handleRevoke() -> HandleDirective {
        return { [weak self] directive, completion in
            guard let revokeItem = try? JSONDecoder().decode(SystemAgentRevokeItem.self, from: directive.payload) else {
                completion(.failed("Invalid payload"))
                return
            }
            defer { completion(.finished) }

            self?.systemDispatchQueue.async { [weak self] in
                self?.post(NuguAgentNotification.System.RevokeDevice(reason: revokeItem.reason, header: directive.header))
            }
        }
    }
    
    func handleNoDirectives() -> HandleDirective {
        return { [weak self] directive, completion in
            defer { completion(.finished) }

            self?.systemDispatchQueue.async { [weak self] in
                self?.post(NuguAgentNotification.System.NoDirective(header: directive.header))
            }
        }
    }
    
    func handleResetConnection() -> HandleDirective {
        return { [weak self] _, completion in
            defer { completion(.finished) }
            
            self?.systemDispatchQueue.async { [weak self] in
                log.info("")
                self?.streamDataRouter.restartReceiveServerInitiatedDirective()
            }
        }
    }
    
    func handleTerminateApp() -> HandleDirective {
        return { [weak self] directive, completion in
            defer { completion(.finished) }
            
            self?.systemDispatchQueue.async { [weak self] in
                log.info("")
                self?.post(NuguAgentNotification.System.TermiateApp(header: directive.header, data: directive.payload))
            }
        }
    }
    
    func handleRequireUpdate() -> HandleDirective {
        return { [weak self] directive, completion in
            defer { completion(.finished) }
            
            self?.systemDispatchQueue.async { [weak self] in
                log.info("")
                self?.post(NuguAgentNotification.System.RequireUpdate(header: directive.header, data: directive.payload))
            }
        }
    }
}

// MARK: - Private (handle directive)

private extension SystemAgent {
    @discardableResult func sendFullContextEvent(
        _ event: Single<Eventable>,
        completion: ((StreamDataState) -> Void)? = nil
    ) -> EventIdentifier {
        let eventIdentifier = EventIdentifier()
        streamDataRouter.sendEvent(
            event,
            eventIdentifier: eventIdentifier,
            context: self.contextManager.rxContexts(),
            property: self.capabilityAgentProperty, completion: completion
        ).subscribe().disposed(by: disposeBag)
        return eventIdentifier
    }
}

// MARK: - Observer

extension Notification.Name {
    static let systemAgentDidReceiveExceptionFail = Notification.Name("com.sktelecom.romaine.notification.name.system_agent_did_receive_exception_fail")
    static let systemAgentDidReceiveExceptionWarning = Notification.Name("com.sktelecom.romaine.notification.name.system_agent_did_receive_exception_warning")
    static let systemAgentDidReceiveRevokeDevice = Notification.Name("com.sktelecom.romaine.notification.name.system_agent_did_revoke_device")
    static let systemAgentDidReceiveNoDirective = Notification.Name("com.sktelecom.romaine.notification.name.system_agent_no_directive")
    static let systemAgentDidReceiveTermiateApp =
        Notification.Name("com.sktelecom.romaine.notification.name.system_agent_termiate_app")
    static let systemAgentDidReceiveRequireUpdate =
        Notification.Name("com.sktelecom.romaine.notification.name.system_agent_require_update")
}

public extension NuguAgentNotification {
    enum System {
        public struct Exception: TypedNotification {
            public static let name: Notification.Name = .systemAgentDidReceiveExceptionFail
            public let code: SystemAgentExceptionCode.Fail
            public let header: Downstream.Header
            
            public static func make(from: [String: Any]) -> Exception? {
                guard let code = from["code"] as? SystemAgentExceptionCode.Fail,
                      let header = from["header"] as? Downstream.Header else { return nil }
                
                return Exception(code: code, header: header)
            }
        }
        
        public struct ExceptionWarning: TypedNotification {
            public static let name: Notification.Name = .systemAgentDidReceiveExceptionWarning
            public let code: SystemAgentExceptionCode.Warning
            public let header: Downstream.Header
            
            public static func make(from: [String: Any]) -> ExceptionWarning? {
                guard let code = from["code"] as? SystemAgentExceptionCode.Warning,
                      let header = from["header"] as? Downstream.Header else { return nil }
                
                return ExceptionWarning(code: code, header: header)
            }
        }
        
        public struct RevokeDevice: TypedNotification {
            static public var name: Notification.Name = .systemAgentDidReceiveRevokeDevice
            public let reason: SystemAgentRevokeReason
            public let header: Downstream.Header
            
            public static func make(from: [String: Any]) -> RevokeDevice? {
                guard let reason = from["reason"] as? SystemAgentRevokeReason,
                      let header = from["header"] as? Downstream.Header else { return nil }
                
                return RevokeDevice(reason: reason, header: header)
            }
        }
        
        public struct NoDirective: TypedNotification {
            static public var name: Notification.Name = .systemAgentDidReceiveNoDirective
            public let header: Downstream.Header
            
            public static func make(from: [String: Any]) -> NoDirective? {
                guard let header = from["header"] as? Downstream.Header else { return nil }
                
                return NoDirective(header: header)
            }
        }
        
        public struct TermiateApp: TypedNotification {
            static public var name: Notification.Name = .systemAgentDidReceiveTermiateApp
            public let header: Downstream.Header
            public let data: Data
            
            public static func make(from: [String : Any]) -> TermiateApp? {
                guard let header = from["header"] as? Downstream.Header,
                      let data = from["data"] as? Data else { return nil }
                
                return TermiateApp(header: header, data: data)
            }
        }
        
        public struct RequireUpdate: TypedNotification {
            static public var name : Notification.Name = .systemAgentDidReceiveRequireUpdate
            public let header: Downstream.Header
            public let data: Data
            
            public static func make(from: [String : Any]) -> RequireUpdate? {
                guard let header = from["header"] as? Downstream.Header,
                      let data = from["data"] as? Data else { return nil }
                
                return RequireUpdate(header: header, data: data)
            }
        }
    }
}
