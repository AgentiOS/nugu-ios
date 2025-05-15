//
//  MessageAgent.swift
//  NuguAgents
//
//  Created by yonghoonKwon on 2021/01/06.
//  Copyright (c) 2020 SK Telecom Co., Ltd. All rights reserved.
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
import Combine

import NuguCore

public final class MessageAgent: MessageAgentProtocol {
    public var capabilityAgentProperty: CapabilityAgentProperty = CapabilityAgentProperty(category: .message, version: "1.5")
    
    // MessageAgentProtocol
    public weak var delegate: MessageAgentDelegate?
    
    // private
    private let directiveSequencer: DirectiveSequenceable
    private let contextManager: ContextManageable
    private let upstreamDataSender: UpstreamDataSendable
    private let messageDispatchQueue = DispatchQueue(label: "com.sktelecom.romaine.message_agent", qos: .userInitiated)
    private let interactionControlManager: InteractionControlManageable
    private var currentInteractionControl: InteractionControl?
    
    private var cancellables: Set<AnyCancellable> = []
    
    // Handleable Directive
    private lazy var handleableDirectiveInfos: [DirectiveHandleInfo] = [
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "SendCandidates", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleSendCandidates),
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "SendMessage", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleSendMessage)
    ]
    
    deinit {
        contextManager.removeProvider(contextInfoProvider)
    }
    
    public init(
        directiveSequencer: DirectiveSequenceable,
        contextManager: ContextManageable,
        upstreamDataSender: UpstreamDataSendable,
        interactionControlManager: InteractionControlManageable
    ) {
        self.directiveSequencer = directiveSequencer
        self.contextManager = contextManager
        self.upstreamDataSender = upstreamDataSender
        self.interactionControlManager = interactionControlManager
        
        contextManager.addProvider(contextInfoProvider)
        directiveSequencer.add(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
    }
    
    public lazy var contextInfoProvider: ContextInfoProviderType = { [weak self] completion in
        guard let self = self else { return }
        
        var payload = [String: AnyHashable?]()
        
        if let context = self.delegate?.messageAgentRequestContext(),
            let contextData = try? JSONEncoder().encode(context),
            let contextDictionary = try? JSONSerialization.jsonObject(with: contextData, options: []) as? [String: AnyHashable] {
            payload = contextDictionary
        }
        
        payload["version"] = self.capabilityAgentProperty.version
        
        completion(ContextInfo(contextType: .capability, name: self.capabilityAgentProperty.name, payload: payload.compactMapValues { $0 }))
    }
}

// MARK: - MessageAgentProtocol

public extension MessageAgent {
    @discardableResult func requestSendCandidates(
        payload: MessageAgentDirectivePayload.SendCandidates,
        header: Downstream.Header?,
        completion: ((StreamDataState) -> Void)?
    ) -> String {
        let event = Event(
            typeInfo: .candidatesListed(interactionControl: currentInteractionControl, service: payload.service),
            playServiceId: payload.playServiceId,
            referrerDialogRequestId: header?.dialogRequestId
        )
        
        return sendFullContextEvent(event) { [weak self] state in
            completion?(state)
            
            self?.messageDispatchQueue.async { [weak self] in
                guard let self else { return }
                switch state {
                case .finished, .error:
                    currentInteractionControl = nil
                    
                    if let interactionControl = payload.interactionControl {
                        interactionControlManager.finish(
                            mode: interactionControl.mode,
                            category: self.capabilityAgentProperty.category
                        )
                    }
                default:
                    break
                }
            }
        }.dialogRequestId
    }
}

// MARK: - Private(Directive)

private extension MessageAgent {
    func handleSendCandidates() -> HandleDirective {
        return { [weak self] directive, completion in
            
            
            self?.messageDispatchQueue.async { [weak self] in
                guard let self = self, let delegate = self.delegate else {
                    completion(.canceled)
                    return
                }
                
                guard let candidatesItem = try? JSONDecoder().decode(MessageAgentDirectivePayload.SendCandidates.self, from: directive.payload) else {
                    completion(.failed("Invalid payload"))
                    return
                }
                
                if let interactionControl = candidatesItem.interactionControl {
                    self.currentInteractionControl = interactionControl
                    self.interactionControlManager.start(
                        mode: interactionControl.mode,
                        category: self.capabilityAgentProperty.category
                    )
                }
                
                delegate.messageAgentDidReceiveSendCandidates(
                    payload: candidatesItem,
                    header: directive.header
                )
                
                completion(.finished)
            }
        }
    }
    
    func handleSendMessage() -> HandleDirective {
        return { [weak self] directive, completion in
            self?.messageDispatchQueue.async { [weak self] in
                guard let self = self, let delegate = self.delegate else {
                    completion(.canceled)
                    return
                }
                
                guard let sendMessageItem = try? JSONDecoder().decode(MessageAgentDirectivePayload.SendMessage.self, from: directive.payload) else {
                    completion(.failed("Invalid payload"))
                    return
                }
                
                var typeInfo: Event.TypeInfo {
                    if let errorCode = delegate.messageAgentDidReceiveSendMessage(payload: sendMessageItem, header: directive.header) {
                        return .sendMessageFailed(recipient: sendMessageItem.recipient, errorCode: errorCode, service: sendMessageItem.service)
                    }
                    
                    return .sendMessageSucceeded(recipient: sendMessageItem.recipient, service: sendMessageItem.service)
                }
                
                self.sendCompactContextEvent(
                    Event(
                        typeInfo: typeInfo,
                        playServiceId: sendMessageItem.playServiceId,
                        referrerDialogRequestId: directive.header.dialogRequestId
                    )
                )
                
                completion(.finished)
            }
        }
    }
}

// MARK: - Private (Event)

private extension MessageAgent {
    @discardableResult func sendCompactContextEvent(
        _ event: Eventable,
        completion: ((StreamDataState) -> Void)? = nil
    ) -> EventIdentifier {
        let eventIdentifier = EventIdentifier()
        upstreamDataSender.sendEvent(
            event,
            eventIdentifier: eventIdentifier,
            context: contextManager.contexts(namespace: capabilityAgentProperty.name),
            property: capabilityAgentProperty,
            completion: completion
        ).store(in: &cancellables)
        return eventIdentifier
    }
    
    @discardableResult func sendFullContextEvent(
        _ event: Eventable,
        completion: ((StreamDataState) -> Void)? = nil
    ) -> EventIdentifier {
        let eventIdentifier = EventIdentifier()
        upstreamDataSender.sendEvent(
            event,
            eventIdentifier: eventIdentifier,
            context: contextManager.contexts(),
            property: capabilityAgentProperty,
            completion: completion
        ).store(in: &cancellables)
        return eventIdentifier
    }
}
