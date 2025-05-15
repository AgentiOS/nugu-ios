//
//  ExtensionAgent.swift
//  NuguAgents
//
//  Created by yonghoonKwon on 25/07/2019.
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
import Combine

import NuguCore

public final class ExtensionAgent: ExtensionAgentProtocol {
    // CapabilityAgentable
    public var capabilityAgentProperty: CapabilityAgentProperty = CapabilityAgentProperty(category: .extension, version: "1.1")
    
    // ExtensionAgentProtocol
    public weak var delegate: ExtensionAgentDelegate?
    
    // private
    private let directiveSequencer: DirectiveSequenceable
    private let contextManager: ContextManageable
    private let upstreamDataSender: UpstreamDataSendable
    
    // Handleable Directive
    private lazy var handleableDirectiveInfos = [
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "Action", blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil), directiveHandler: handleAction)
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        upstreamDataSender: UpstreamDataSendable,
        contextManager: ContextManageable,
        directiveSequencer: DirectiveSequenceable
    ) {
        self.upstreamDataSender = upstreamDataSender
        self.contextManager = contextManager
        self.directiveSequencer = directiveSequencer
        
        contextManager.addProvider(contextInfoProvider)
        directiveSequencer.add(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
    }
    
    deinit {
        contextManager.removeProvider(contextInfoProvider)
        directiveSequencer.remove(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
    }
    
    public lazy var contextInfoProvider: ContextInfoProviderType = { [weak self] completion in
        guard let self else { return }
        
        let payload: [String: AnyHashable?] = [
            "version": capabilityAgentProperty.version,
            "data": delegate?.extensionAgentRequestContext()
        ]
        
        completion(
            ContextInfo(contextType: .capability, name: capabilityAgentProperty.name, payload: payload.compactMapValues { $0 })
        )
    }
}

// MARK: - ExtensionAgentProtocol

public extension ExtensionAgent {
    @discardableResult func requestCommand(data: [String: AnyHashable], playServiceId: String, completion: ((StreamDataState) -> Void)?) -> String {
        return sendCompactContextEvent(Event(
            typeInfo: .commandIssued(data: data),
            playServiceId: playServiceId,
            referrerDialogRequestId: nil
        ), completion: completion).dialogRequestId
    }
}

// MARK: - Private(Directive)

private extension ExtensionAgent {
    func handleAction() -> HandleDirective {
        return { [weak self] directive, completion in
            guard let self, let delegate else {
                completion(.canceled)
                return
            }
            
            guard let item = try? JSONDecoder().decode(ExtensionAgentItem.self, from: directive.payload) else {
                completion(.failed("Invalid payload"))
                return
            }
            defer { completion(.finished) }

            delegate.extensionAgentDidReceiveAction(
                data: item.data,
                playServiceId: item.playServiceId,
                header: directive.header,
                completion: { [weak self] (isSuccess) in
                    let typeInfo: Event.TypeInfo = isSuccess ? .actionSucceeded : .actionFailed
                    self?.sendCompactContextEvent(
                        Event(
                            typeInfo: typeInfo,
                            playServiceId: item.playServiceId,
                            referrerDialogRequestId: directive.header.dialogRequestId
                        )
                    )
            })
        }
    }
}

// MARK: - Private (Event)

private extension ExtensionAgent {
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
}
