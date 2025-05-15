//
//  TextAgent.swift
//  NuguAgents
//
//  Created by yonghoonKwon on 17/06/2019.
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

public final class TextAgent: TextAgentProtocol {
    // CapabilityAgentable
    public var capabilityAgentProperty: CapabilityAgentProperty = CapabilityAgentProperty(category: .text, version: "1.8")
    public weak var delegate: TextAgentDelegate?
    
    // Private
    private let contextManager: ContextManageable
    private let upstreamDataSender: UpstreamDataSendable
    private let directiveSequencer: DirectiveSequenceable
    private let dialogAttributeStore: DialogAttributeStoreable
    private let interactionControlManager: InteractionControlManageable
    private let textDispatchQueue = DispatchQueue(label: "com.sktelecom.romaine.text_agent", qos: .userInitiated)
    
    private var currentInteractionControl: InteractionControl?
    
    // Handleable Directives
    private lazy var handleableDirectiveInfos = [
        DirectiveHandleInfo(
            namespace: capabilityAgentProperty.name,
            name: "TextSource",
            blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil),
            directiveHandler: handleTextSource
        ),
        DirectiveHandleInfo(
            namespace: capabilityAgentProperty.name,
            name: "TextRedirect",
            blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil),
            directiveHandler: handleTextRedirect
        ),
        DirectiveHandleInfo(
            namespace: capabilityAgentProperty.name,
            name: "ExpectTyping",
            blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil),
            directiveHandler: handleExpectTyping
        )
    ]
    
    private var cancellables: Set<AnyCancellable> = []
    private var expectTyping: TextAgentExpectTyping? {
        didSet {
            guard oldValue?.dialogRequestId != expectTyping?.dialogRequestId else { return }
            log.debug("expectTyping is changed from:\(oldValue?.dialogRequestId ?? "nil") to:\(expectTyping?.dialogRequestId ?? "nil")")
            
            // TextAgent의 ExpectTyping은 함꼐 내려온 template에 종속적으로 동작해야 해서 messasgeId 대신 dialogRequestId를 사용한다.
            if let oldDialogRequestId = oldValue?.dialogRequestId {
                // Remove last attributes
                dialogAttributeStore.removeAttributes(key: oldDialogRequestId)
            }
            
            if let dialogRequestId = expectTyping?.dialogRequestId,
               let payload = expectTyping?.payload.dictionary {
                // Store attributes
                dialogAttributeStore.setAttributes(payload.compactMapValues { $0 }, key: dialogRequestId)
            }
        }
    }
    
    public init(
        contextManager: ContextManageable,
        upstreamDataSender: UpstreamDataSendable,
        directiveSequencer: DirectiveSequenceable,
        dialogAttributeStore: DialogAttributeStoreable,
        interactionControlManager: InteractionControlManageable
    ) {
        self.contextManager = contextManager
        self.upstreamDataSender = upstreamDataSender
        self.directiveSequencer = directiveSequencer
        self.dialogAttributeStore = dialogAttributeStore
        self.interactionControlManager = interactionControlManager
        
        directiveSequencer.add(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
        contextManager.addProvider(contextInfoProvider)
    }
    
    deinit {
        directiveSequencer.remove(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
        contextManager.removeProvider(contextInfoProvider)
    }
    
    public lazy var contextInfoProvider: ContextInfoProviderType = { [weak self] completion in
        guard let self else { return }
        
        let payload: [String: AnyHashable] = ["version": capabilityAgentProperty.version]
        completion(ContextInfo(contextType: .capability, name: capabilityAgentProperty.name, payload: payload))
    }
}

// MARK: - TextAgentProtocol

extension TextAgent {
    @discardableResult public func requestTextInput(
        text: String,
        token: String?,
        source: TextInputSource?,
        requestType: TextAgentRequestType,
        service: [String: AnyHashable]?,
        completion: ((StreamDataState) -> Void)?
    ) -> String {
        sendFullContextEvent(
            textInput(
                text: text,
                token: token,
                source: source,
                requestType: requestType,
                service: service
            ),
            completion: completion
        )
        .dialogRequestId
    }
    
    @discardableResult public func requestTextInput(
        text: String,
        token: String?,
        playServiceId: String?,
        source: TextInputSource?,
        service: [String: AnyHashable]?,
        completion: ((StreamDataState) -> Void)?
    ) -> EventIdentifier {
        sendFullContextEvent(
            textInput(
                text: text,
                token: token,
                playServiceId: playServiceId,
                source: source,
                service: service
            ),
            completion: completion
        )
    }
}

// MARK: - ContextInfoDelegate

extension TextAgent: ContextInfoProvidable {
    public func requestContextInfo(completion: (ContextInfo?) -> Void) {
        let payload: [String: AnyHashable] = ["version": capabilityAgentProperty.version]
        completion(ContextInfo(contextType: .capability, name: capabilityAgentProperty.name, payload: payload))
    }
}

// MARK: - Private(Directive)

private extension TextAgent {
    func handleTextSource() -> HandleDirective {
        return { [weak self] directive, completion in
            guard let payload = try? JSONDecoder().decode(TextAgentSourceItem.self, from: directive.payload) else {
                completion(.failed("Invalid payload"))
                return
            }
            defer { completion(.finished) }
            
            self?.textDispatchQueue.async { [weak self] in
                guard let self else { return }
                guard delegate?.textAgentShouldHandleTextSource(directive: directive) != false else {
                    sendCompactContextEvent(Event(
                        typeInfo: .textSourceFailed(token: payload.token, playServiceId: payload.playServiceId, errorCode: "NOT_SUPPORTED_STATE"),
                        referrerDialogRequestId: directive.header.dialogRequestId
                    ))
                    return
                }
                
                let requestType: TextAgentRequestType
                if let playServiceId = payload.playServiceId {
                    requestType = .specific(playServiceId: playServiceId)
                } else {
                    requestType = .dialog
                }
                
                sendFullContextEvent(textInput(
                    text: payload.text,
                    token: payload.token,
                    requestType: requestType,
                    service: payload.service,
                    referrerDialogRequestId: directive.header.dialogRequestId
                ))
            }
        }
    }
    
    func handleTextRedirect() -> HandleDirective {
        return { [weak self] directive, completion in
            self?.textDispatchQueue.async { [weak self] in
                guard let self else {
                    completion(.canceled)
                    return
                }
                
                guard let payload = try? JSONDecoder().decode(TextAgentRedirectPayload.self, from: directive.payload) else {
                    completion(.failed("Invalid payload"))
                    return
                }
                defer { completion(.finished) }
                
                if let interactionControl = payload.interactionControl {
                    currentInteractionControl = interactionControl
                    interactionControlManager.start(mode: interactionControl.mode, category: capabilityAgentProperty.category)
                }
                
                let interactionHandler = { [weak self] (state: StreamDataState) in
                    guard let self else { return }
                    
                    switch state {
                    case .finished, .error:
                        currentInteractionControl = nil
                        
                        if let interactionControl = payload.interactionControl {
                            interactionControlManager.finish(mode: interactionControl.mode, category: capabilityAgentProperty.category)
                        }
                    default:
                        break
                    }
                }
                
                guard delegate?.textAgentShouldHandleTextRedirect(directive: directive) != false else {
                    sendCompactContextEvent(Event(
                        typeInfo: .textRedirectFailed(
                            token: payload.token,
                            playServiceId: payload.playServiceId,
                            errorCode: "NOT_SUPPORTED_STATE",
                            interactionControl: currentInteractionControl
                        ),
                        referrerDialogRequestId: directive.header.dialogRequestId
                    ), completion: interactionHandler)
                    return
                }
                
                let requestType: TextAgentRequestType
                if let playServiceId = payload.targetPlayServiceId {
                    requestType = .specific(playServiceId: playServiceId)
                } else {
                    requestType = .normal
                }
                
                sendFullContextEvent(
                    textInput(
                    text: payload.text,
                    token: payload.token,
                    requestType: requestType,
                    service: payload.service,
                    referrerDialogRequestId: directive.header.dialogRequestId
                ), completion: interactionHandler)
            }
        }
    }
    
    func handleExpectTyping() -> HandleDirective {
        return { [weak self] directive, completion in
            guard let self else {
                completion(.canceled)
                return
            }
            
            defer { completion(.finished) }
            expectTyping = nil
            
            if delegate?.textAgentShouldTyping(directive: directive) == true {
                guard let payload = try? JSONDecoder().decode(TextAgentExpectTyping.Payload.self, from: directive.payload) else { return }
                
                textDispatchQueue.async { [weak self] in
                    guard let self else { return }
                    expectTyping = TextAgentExpectTyping(
                        messageId: directive.header.messageId,
                        dialogRequestId: directive.header.dialogRequestId,
                        payload: payload
                    )
                }
            }
        }
    }
}

// MARK: - Private(Event)

private extension TextAgent {
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
        _ event: AnyPublisher<Eventable, Error>,
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

// MARK: - Private(Eventable)

private extension TextAgent {
    func textInput(
        text: String,
        token: String?,
        source: TextInputSource? = nil,
        requestType: TextAgentRequestType,
        service: [String: AnyHashable]? = nil,
        referrerDialogRequestId: String? = nil
    ) -> AnyPublisher<Eventable, Error> {
        Future<Eventable, Error> { [weak self] promise in
            self?.textDispatchQueue.async { [weak self] in
                var attributes: [String: AnyHashable] {
                    if case let .specific(playServiceId) = requestType {
                        return ["playServiceId": playServiceId]
                    }
                    
                    var attributes = [String: AnyHashable]()
                    if case .dialog = requestType,
                       let expectTypingDialogRequestId = self?.expectTyping?.dialogRequestId,
                       let expectTypingAttribute = self?.dialogAttributeStore.requestAttributes(key: expectTypingDialogRequestId) {
                        attributes.merge(expectTypingAttribute)
                    }
                    
                    if let source = source {
                        attributes["source"] = source.description
                    }
                    
                    if let interactionControl = self?.currentInteractionControl,
                       let interactionControlData = try? JSONEncoder().encode(interactionControl),
                       let interactionControlDictionary = try? JSONSerialization.jsonObject(with: interactionControlData, options: []) as? [String: AnyHashable] {
                        attributes["interactionControl"] = interactionControlDictionary
                    }
                    
                    if let service = service {
                        attributes["service"] = service
                    }
                    
                    return attributes
                }
                
                promise(.success(Event(
                    typeInfo: .textInput(text: text, token: token, attributes: attributes),
                    referrerDialogRequestId: referrerDialogRequestId
                )))
            }
        }.eraseToAnyPublisher()
    }
    
    func textInput(
        text: String,
        token: String?,
        playServiceId: String?,
        source: TextInputSource? = nil,
        service: [String: AnyHashable]? = nil,
        referrerDialogRequestId: String? = nil
    ) -> AnyPublisher<Eventable, Error> {
        Future<Eventable, Error> { [weak self] promise in
            self?.textDispatchQueue.async { [weak self] in
                var attributes = [String: AnyHashable]()
                if let expectTypingDialogRequestId = self?.expectTyping?.dialogRequestId,
                   let expectTypingAttribute = self?.dialogAttributeStore.requestAttributes(key: expectTypingDialogRequestId) {
                    attributes.merge(expectTypingAttribute)
                }
                
                if let playServiceId = playServiceId {
                    attributes["playServiceId"] = playServiceId
                }
                
                if let source = source {
                    attributes["source"] = source.description
                }
                
                if let interactionControl = self?.currentInteractionControl,
                   let interactionControlData = try? JSONEncoder().encode(interactionControl),
                   let interactionControlDictionary = try? JSONSerialization.jsonObject(with: interactionControlData, options: []) as? [String: AnyHashable] {
                    attributes["interactionControl"] = interactionControlDictionary
                }
                
                if let service = service {
                    attributes["service"] = service
                }
                
                promise(.success(Event(
                    typeInfo: .textInput(text: text, token: token, attributes: attributes),
                    referrerDialogRequestId: referrerDialogRequestId
                )))

            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - TextAgentExpectTyping Decorator

private extension TextAgentExpectTyping.Payload {
    var dictionary: [String: AnyHashable?] {
        return [
            "asrContext": asrContext,
            "domainTypes": domainTypes,
            "playServiceId": playServiceId,
            "service": service
        ]
    }
}
