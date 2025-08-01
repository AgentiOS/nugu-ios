//
//  ASRAgent.swift
//  NuguAgents
//
//  Created by MinChul Lee on 17/04/2019.
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
import AVFoundation
import Accelerate

import NuguCore
import NuguUtils
import JadeMarble

import RxSwift

public final class ASRAgent: ASRAgentProtocol {
    // CapabilityAgentable
    public var capabilityAgentProperty: CapabilityAgentProperty = CapabilityAgentProperty(category: .automaticSpeechRecognition, version: "1.9")
    private let playSyncProperty = PlaySyncProperty(layerType: .asr, contextType: .sound)
    
    public weak var delegate: ASRAgentDelegate?
    
    // Private
    private let focusManager: FocusManageable
    private let contextManager: ContextManageable
    private let directiveSequencer: DirectiveSequenceable
    private let upstreamDataSender: UpstreamDataSendable
    private let dialogAttributeStore: DialogAttributeStoreable
    private let sessionManager: SessionManageable
    private let playSyncManager: PlaySyncManageable
    private let interactionControlManager: InteractionControlManageable
    
    private let eventTimeFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        // IMF-fixdate https://tools.ietf.org/html/rfc7231#section-7.1.1.1
        dateFormatter.dateFormat = "EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        return dateFormatter
    }()
    
    private var endPointDetector: EndPointDetectable?
    
    private let asrDispatchQueue = DispatchQueue(label: "com.sktelecom.romaine.asr_agent", qos: .userInitiated)
    
    // Observers
    private let notificationCenter = NotificationCenter.default
    private var playSyncObserver: Any?
    private var directiveReceiveObserver: Any?
    private var isVoiceProcessingEnabled = false
    
    public var options: ASROptions = ASROptions(endPointing: .client)
    private(set) public var asrState: ASRState = .idle {
        didSet {
            log.info("From:\(oldValue) To:\(asrState)")
            
            // `ASRRequest` -> `FocusState` -> EndPointDetector` -> `ASRAgentDelegate`
            // release asrRequest
            if asrState == .idle {
                switch asrResult {
                case let .cancel(_, dialogRequestId):
                    guard let cancelDialogRequestId = dialogRequestId else { fallthrough }
                    guard asrRequest?.eventIdentifier.dialogRequestId == cancelDialogRequestId else {
                        log.info("asrRequest's dialogRequestId is not correspond cancel dialogRequestId")
                        break
                    }
                    fallthrough
                default:
                    asrRequest = nil
                    releaseFocusIfNeeded()
                }
            }
            
            // Stop EPD
            if [.listening(), .recognizing].contains(asrState) == false {
                endPointDetector?.stop()
                endPointDetector?.delegate = nil
                endPointDetector = nil
            }
            
            // Notify delegates only if the agent's status changes.
            if oldValue != asrState {
                post(NuguAgentNotification.ASR.State(state: asrState))
            }
        }
    }
    
    private var asrResult: ASRResult? {
        didSet {
            guard let asrRequest = asrRequest, let asrResult = asrResult else {
                asrState = .idle
                expectSpeech = nil
                log.error("ASR request: \(String(describing: asrRequest)), result: \(String(describing: asrResult))")
                return
            }
            log.info("asrResult: \(asrResult)")
            
            // `ASRState` -> Event -> `expectSpeechDirective` -> `ASRAgentDelegate`
            switch asrResult {
            case .none:
                asrState = .idle
                expectSpeech = nil
            case .partial:
                break
            case .complete:
                // Complete result는 asr state가 Idle로 변경된 이후에 처리되기 때문에 handleNotify에서 직접 처리
                return
            case .cancel:
                asrState = .idle
                upstreamDataSender.cancelEvent(dialogRequestId: asrRequest.eventIdentifier.dialogRequestId)
                directiveSequencer.cancelDirective(dialogRequestId: asrRequest.eventIdentifier.dialogRequestId)
                sendCompactContextEvent(Event(
                    typeInfo: .stopRecognize,
                    dialogAttributes: expectSpeech?.messageId == nil ? nil : dialogAttributeStore.getAttributes(key: expectSpeech!.messageId),
                    referrerDialogRequestId: asrRequest.eventIdentifier.dialogRequestId
                ).rx)
                clearExpectSpeechIfNeeded(asrRequest: asrRequest)
            case .cancelExpectSpeech:
                asrState = .idle
                directiveSequencer.cancelDirective(dialogRequestId: asrRequest.eventIdentifier.dialogRequestId)
                sendCompactContextEvent(Event(
                    typeInfo: .listenFailed,
                    dialogAttributes: expectSpeech?.messageId == nil ? nil : dialogAttributeStore.getAttributes(key: expectSpeech!.messageId),
                    referrerDialogRequestId: asrRequest.referrerDialogRequestId
                ).rx)
                expectSpeech = nil
            case .error(let error, _):
                asrState = .idle
                switch error {
                case NetworkError.timeout:
                    sendCompactContextEvent(Event(
                        typeInfo: .responseTimeout,
                        dialogAttributes: expectSpeech?.messageId == nil ? nil : dialogAttributeStore.getAttributes(key: expectSpeech!.messageId),
                        referrerDialogRequestId: asrRequest.eventIdentifier.dialogRequestId
                    ).rx)
                case ASRError.listeningTimeout:
                    upstreamDataSender.cancelEvent(dialogRequestId: asrRequest.eventIdentifier.dialogRequestId)
                    sendFullContextEvent(Event(
                        typeInfo: .listenTimeout,
                        dialogAttributes: expectSpeech?.messageId == nil ? nil : dialogAttributeStore.getAttributes(key: expectSpeech!.messageId),
                        referrerDialogRequestId: asrRequest.eventIdentifier.dialogRequestId
                    ).rx)
                case ASRError.listenFailed:
                    upstreamDataSender.cancelEvent(dialogRequestId: asrRequest.eventIdentifier.dialogRequestId)
                    sendCompactContextEvent(Event(
                        typeInfo: .listenFailed,
                        dialogAttributes: expectSpeech?.messageId == nil ? nil : dialogAttributeStore.getAttributes(key: expectSpeech!.messageId),
                        referrerDialogRequestId: asrRequest.eventIdentifier.dialogRequestId
                    ).rx)
                case ASRError.recognizeFailed:
                    break
                default:
                    break
                }
                expectSpeech = nil
            }
            
            post(NuguAgentNotification.ASR.Result(result: asrResult, dialogRequestId: asrRequest.eventIdentifier.dialogRequestId))
        }
    }
    
    // For Recognize Event
    @Atomic private var asrRequest: ASRRequest?
    private var attachmentSeq: Int32 = 0
    
    private lazy var disposeBag = DisposeBag()
    private var expectSpeech: ASRExpectSpeech? {
        didSet {
            if oldValue?.messageId != expectSpeech?.messageId {
                log.debug("From:\(oldValue?.messageId ?? "nil") To:\(expectSpeech?.messageId ?? "nil")")
            }
            if let dialogRequestId = expectSpeech?.dialogRequestId {
                sessionManager.activate(dialogRequestId: dialogRequestId, category: .automaticSpeechRecognition)
                interactionControlManager.start(mode: .multiTurn, category: capabilityAgentProperty.category)
            } else if let messageId = oldValue?.messageId {
                playSyncManager.endPlay(property: playSyncProperty)
                dialogAttributeStore.removeAttributes(key: messageId)
                interactionControlManager.finish(mode: .multiTurn, category: capabilityAgentProperty.category)
            }
            if let dialogRequestId = oldValue?.dialogRequestId {
                sessionManager.deactivate(dialogRequestId: dialogRequestId, category: .automaticSpeechRecognition)
            }
        }
    }
    
    // Handleable Directives
    private lazy var handleableDirectiveInfos = [
        DirectiveHandleInfo(
            namespace: capabilityAgentProperty.name,
            name: "ExpectSpeech",
            blockingPolicy: BlockingPolicy(blockedBy: .audio, blocking: .audioOnly),
            preFetch: prefetchExpectSpeech,
            cancelDirective: cancelExpectSpeech,
            directiveHandler: handleExpectSpeech
        ),
        DirectiveHandleInfo(
            namespace: capabilityAgentProperty.name,
            name: "NotifyResult",
            blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil),
            directiveHandler: handleNotifyResult
        ),
        DirectiveHandleInfo(
            namespace: capabilityAgentProperty.name,
            name: "CancelRecognize",
            blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil),
            directiveHandler: handleCancelRecognize
        )
    ]
    
    public init(
        focusManager: FocusManageable,
        upstreamDataSender: UpstreamDataSendable,
        contextManager: ContextManageable,
        directiveSequencer: DirectiveSequenceable,
        dialogAttributeStore: DialogAttributeStoreable,
        sessionManager: SessionManageable,
        playSyncManager: PlaySyncManageable,
        interactionControlManager: InteractionControlManageable
    ) {
        self.focusManager = focusManager
        self.upstreamDataSender = upstreamDataSender
        self.directiveSequencer = directiveSequencer
        self.contextManager = contextManager
        self.dialogAttributeStore = dialogAttributeStore
        self.sessionManager = sessionManager
        self.playSyncManager = playSyncManager
        self.interactionControlManager = interactionControlManager
        
        addPlaySyncObserver(playSyncManager)
        contextManager.addProvider(contextInfoProvider)
        focusManager.add(channelDelegate: self)
        directiveSequencer.add(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
    }
    
    deinit {
        if let playSyncObserver = playSyncObserver {
            notificationCenter.removeObserver(playSyncObserver)
        }
        
        if let directiveReceiveObserver = directiveReceiveObserver {
            notificationCenter.removeObserver(directiveReceiveObserver)
        }
        
        contextManager.removeProvider(contextInfoProvider)
        directiveSequencer.remove(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
    }
    
    public lazy var contextInfoProvider: ContextInfoProviderType = { [weak self] completion in
        guard let self = self else { return }
        
        let payload: [String: AnyHashable?] = [
            "version": self.capabilityAgentProperty.version,
            "engine": "skt",
            "state": self.asrState.value,
            "initiator": self.asrRequest?.initiator.value
        ]
        completion(ContextInfo(contextType: .capability, name: self.capabilityAgentProperty.name, payload: payload.compactMapValues { $0 }))
    }
}

// MARK: - ASRAgentProtocol

public extension ASRAgent {
    @discardableResult func startRecognition(
        initiator: ASRInitiator,
        service: [String: AnyHashable]?,
        options: ASROptions?,
        completion: ((StreamDataState) -> Void)?
    ) -> String {
        log.debug("startRecognition, initiator: \(initiator)")
        let eventIdentifier = EventIdentifier()
        
        asrDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            guard [.listening(), .recognizing, .busy].contains(self.asrState) == false else {
                log.warning("Not permitted in current state \(self.asrState)")
                completion?(.error(ASRError.listenFailed))
                return
            }
            
            startRecognition(
                initiator: initiator,
                eventIdentifier: eventIdentifier,
                service: service,
                options: options,
                completion: completion
            )
        }
        
        return eventIdentifier.dialogRequestId
    }
    
    func stopSpeech() {
        log.debug("")
        asrDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            switch self.asrState {
            case .listening, .recognizing:
                self.executeStopSpeech()
            case .idle, .expectingSpeech, .busy:
                log.warning("Not permitted in current state \(self.asrState)")
                return
            }
        }
    }
    
    func putAudioBuffer(buffer: AVAudioPCMBuffer) {
        analyzeBuffer(buffer)
        endPointDetector?.putAudioBuffer(buffer: buffer)
    }
    
    func stopRecognition() {
        log.debug("")
        asrDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.expectSpeech = nil
            if self.asrState != .idle {
                self.asrResult = .cancel(dialogRequestId: asrRequest?.eventIdentifier.dialogRequestId)
            }
        }
    }
    
    func setVoiceProcessingEnabled(_ active: Bool) {
        isVoiceProcessingEnabled = active
    }
    
    func postponeSilenceTimeout() -> Bool {
        guard let endPointDetector else { return false }
        return endPointDetector.resetEPDTimeout()
    }
}

// MARK: - FocusChannelDelegate

extension ASRAgent: FocusChannelDelegate {
    public func focusChannelPriority() -> FocusChannelPriority {
        guard isVoiceProcessingEnabled == false else {
            return .init(requestPriority: 200, maintainPriority: 300)
        }
        switch asrRequest?.initiator {
        case .expectSpeech: return .dmRecognition
        default: return .userRecognition
        }
    }
    
    public func focusChannelDidChange(focusState: FocusState) {
        asrDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            
            log.info("focus: \(focusState) asr state: \(self.asrState)")
            switch (focusState, self.asrState) {
            case (.foreground, let asrState) where [.idle, .expectingSpeech].contains(asrState):
                self.executeStartCapture()
                // Ignore (foreground, [listening, recognizing, busy])
            case (.foreground, _):
                break
                // Not permitted background
            case (_, let asrState) where [.listening(), .recognizing].contains(asrState):
                self.asrResult = .cancel()
            case (_, .expectingSpeech):
                self.asrResult = .cancelExpectSpeech
            default:
                break
            }
        }
    }
}

// MARK: - EndPointDetectorDelegate

extension ASRAgent: EndPointDetectorDelegate {
    func endPointDetectorDidError() {
        asrDispatchQueue.async { [weak self] in
            self?.asrResult = .error(ASRError.listenFailed)
        }
    }
    
    func endPointDetectorStateChanged(_ state: EndPointDetectorState) {
        asrDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            switch self.asrState {
            case .listening, .recognizing:
                break
            case .idle, .expectingSpeech, .busy:
                log.info("Not permitted in current state \(self.asrState)")
                return
            }
            
            switch state {
            case .idle:
                self.asrResult = .error(ASRError.listenFailed)
            case .listening:
                break
            case .start:
                self.asrState = .recognizing
            case .end, .reachToMaxLength, .finish:
                self.executeStopSpeech()
            case .unknown:
                self.asrResult = .error(ASRError.listenFailed)
            case .timeout:
                self.asrResult = .error(ASRError.listeningTimeout(listenTimeoutFailBeep: self.expectSpeech?.payload.listenTimeoutFailBeep ?? true))
            }
        }
    }
    
    func endPointDetectorSpeechDataExtracted(speechData: Data) {
        asrDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            guard let asrRequest = self.asrRequest  else {
                log.warning("ASRRequest not exist")
                return
            }
            switch self.asrState {
            case .listening, .recognizing:
                break
            case .idle, .expectingSpeech, .busy:
                log.warning("Not permitted in current state \(self.asrState)")
                return
            }
            
            if attachmentSeq == .zero, asrRequest.options.timeout.seconds > Const.epdTimeout {
                var httpHeaderFields = [String: String]()
                if let lastAsrEventTime = UserDefaults.Nugu.lastAsrEventTime {
                    httpHeaderFields["Last-Asr-Event-Time"] = lastAsrEventTime
                }
                upstreamDataSender.sendStream(
                    Event(
                        typeInfo: .recognize(initiator: asrRequest.initiator, options: asrRequest.options, service: asrRequest.service),
                        dialogAttributes: dialogAttributeStore.requestAttributes(key: expectSpeech?.messageId),
                        referrerDialogRequestId: asrRequest.referrerDialogRequestId
                    ).makeEventMessage(
                        property: self.capabilityAgentProperty,
                        eventIdentifier: asrRequest.eventIdentifier,
                        httpHeaderFields: httpHeaderFields,
                        contextPayload: asrRequest.contextPayload
                    )) { [weak self] (state) in
                        self?.asrDispatchQueue.async { [weak self] in
                            guard let self else { return }
                            guard self.asrRequest?.eventIdentifier == asrRequest.eventIdentifier else { return }
                            
                            switch state {
                            case .error(let error):
                                self.asrResult = .error(error)
                            case .sent:
                                UserDefaults.Nugu.lastAsrEventTime = eventTimeFormatter.string(from: Date())
                            case let .received(part):
                                guard part.header.namespace != capabilityAgentProperty.category.name else {
                                    asrRequest.completion?(state)
                                    return
                                }
                                asrState = .idle
                            default:
                                break
                            }
                            
                            asrRequest.completion?(state)
                        }
                    }
            }
            
            let attachment = Attachment(typeInfo: .recognize).makeAttachmentMessage(
                property: self.capabilityAgentProperty,
                dialogRequestId: asrRequest.eventIdentifier.dialogRequestId,
                referrerDialogRequestId: asrRequest.referrerDialogRequestId,
                attachmentSeq: self.attachmentSeq,
                isEnd: false,
                speechData: speechData
            )
            self.upstreamDataSender.sendStream(attachment)
            self.attachmentSeq += 1
            log.debug("request seq: \(self.attachmentSeq-1)")
        }
    }
}

// MARK: - Private (Directive)

private extension ASRAgent {
    func prefetchExpectSpeech() -> PrefetchDirective {
        return { [weak self] directive in
            let payload = try JSONDecoder().decode(ASRExpectSpeech.Payload.self, from: directive.payload)
            
            self?.asrDispatchQueue.async { [weak self] in
                guard let self = self else { return }
                if let playServiceId = payload.playServiceId {
                    self.playSyncManager.startPlay(
                        property: self.playSyncProperty,
                        info: PlaySyncInfo(
                            playStackServiceId: playServiceId,
                            dialogRequestId: directive.header.dialogRequestId,
                            messageId: directive.header.messageId,
                            duration: NuguTimeInterval(seconds: 0)
                        )
                    )
                }
                self.expectSpeech = ASRExpectSpeech(messageId: directive.header.messageId, dialogRequestId: directive.header.dialogRequestId, payload: payload)
                let attributes: [String: AnyHashable?] = [
                    "asrContext": payload.asrContext,
                    "domainTypes": payload.domainTypes,
                    "playServiceId": payload.playServiceId
                ]
                self.dialogAttributeStore.setAttributes(attributes.compactMapValues { $0 }, key: directive.header.messageId)
            }
        }
    }
    
    func handleExpectSpeech() -> HandleDirective {
        return { [weak self] directive, completion in
            defer { completion(.finished) }
            
            self?.asrDispatchQueue.sync { [weak self] in
                guard let self = self, let delegate = self.delegate else { return }
                // ex> TTS 도중 stopRecognition 호출.
                guard let expectSpeech = self.expectSpeech, expectSpeech.messageId == directive.header.messageId else {
                    log.info("Message id does not match")
                    return
                }
                // ex> TTS 도중 wakeup
                guard [.idle, .busy].contains(self.asrState) else {
                    log.warning("ExpectSpeech only allowed in IDLE or BUSY state.")
                    return
                }
                let service = expectSpeech.payload.service
                guard service == nil || delegate.asrAgentWillStartExpectSpeech(service: service) else {
                    log.warning("ExpectSpeech service field is not nil. service: \(String(describing: service))")
                    self.asrResult = nil
                    return
                }
                
                self.asrState = .expectingSpeech
                startRecognition(
                    initiator: .expectSpeech,
                    eventIdentifier: EventIdentifier(),
                    service: service,
                    options: options,
                    completion: nil
                )
            }
        }
    }
    
    func cancelExpectSpeech() -> CancelDirective {
        return { [weak self] directive in
            self?.asrDispatchQueue.async { [weak self] in
                if self?.expectSpeech?.dialogRequestId == directive.header.dialogRequestId {
                    self?.expectSpeech = nil
                }
            }
        }
    }
    
    func handleNotifyResult() -> HandleDirective {
        return { [weak self] directive, completion in
            self?.asrDispatchQueue.async { [weak self] in
                guard let self = self else { return }
                guard let item = try? JSONDecoder().decode(ASRNotifyResult.self, from: directive.payload) else {
                    completion(.failed("Invalid payload"))
                    return
                }
                defer { completion(.finished) }
                self.endPointDetector?.handleNotifyResult(item.state)
                switch item.state {
                case .partial:
                    self.asrResult = .partial(text: item.result ?? "", header: directive.header)
                case .complete:
                    let asrResult: ASRResult = .complete(text: item.result ?? "", header: directive.header, requestType: item.requestType)
                    self.asrResult = asrResult
                    expectSpeech = nil
                    post(NuguAgentNotification.ASR.Result(result: asrResult, dialogRequestId: directive.header.dialogRequestId))
                case .none where item.asrErrorCode != nil:
                    self.asrResult = .error(ASRError.recognizeFailed, header: directive.header)
                case .none:
                    self.asrResult = .none(header: directive.header)
                case .error:
                    self.asrResult = .error(ASRError.recognizeFailed, header: directive.header)
                default:
                    // TODO: after server preparation.
                    break
                }
            }
        }
    }
    
    func handleCancelRecognize() -> HandleDirective {
        return { [weak self] _, completion in
            guard let self = self else {
                completion(.canceled)
                return
            }
            
            self.asrDispatchQueue.async { [weak self] in
                guard let self = self else {
                    completion(.canceled)
                    return
                }
                defer { completion(.finished) }
                
                if self.asrState != .idle {
                    self.asrResult = .cancel()
                }
            }
        }
    }
}

// MARK: - Private (Event)

private extension ASRAgent {
    @discardableResult func sendCompactContextEvent(
        _ event: Single<Eventable>,
        completion: ((StreamDataState) -> Void)? = nil
    ) -> EventIdentifier {
        let eventIdentifier = EventIdentifier()
        upstreamDataSender.sendEvent(
            event,
            eventIdentifier: eventIdentifier,
            context: self.contextManager.rxContexts(namespace: self.capabilityAgentProperty.name),
            property: self.capabilityAgentProperty,
            completion: completion
        ).subscribe().disposed(by: disposeBag)
        return eventIdentifier
    }
    
    @discardableResult func sendFullContextEvent(
        _ event: Single<Eventable>,
        completion: ((StreamDataState) -> Void)? = nil
    ) -> EventIdentifier {
        let eventIdentifier = EventIdentifier()
        upstreamDataSender.sendEvent(
            event,
            eventIdentifier: eventIdentifier,
            context: self.contextManager.rxContexts(),
            property: self.capabilityAgentProperty,
            completion: completion
        ).subscribe().disposed(by: disposeBag)
        return eventIdentifier
    }
}

// MARK: - Private(FocusManager)

private extension ASRAgent {
    func releaseFocusIfNeeded() {
        guard asrState == .idle else {
            log.info("Not permitted in current state, \(asrState)")
            return
        }
        
        focusManager.releaseFocus(channelDelegate: self)
    }
    
    func clearExpectSpeechIfNeeded(asrRequest: ASRRequest) {
        guard let expectSpeechDialogRequestId = expectSpeech?.dialogRequestId else { return }
        guard let asrRequestDialogRequestId = asrRequest.referrerDialogRequestId else {
            expectSpeech = nil
            return
        }
        
        guard expectSpeechDialogRequestId == asrRequestDialogRequestId else {
            log.info("new expectSpeechDirective received, dialogRequestId: \(expectSpeechDialogRequestId)")
            return
        }
        expectSpeech = nil
    }
}

// MARK: - Private(EndPointDetector)

private extension ASRAgent {
    /// asrDispatchQueue
    func executeStartCapture() {
        guard let asrRequest = asrRequest else {
            log.error("ASRRequest not exist")
            asrResult = .cancel()
            return
        }
        
        asrRequest.completion?(.prepared)
        
        if asrRequest.options.timeout.seconds <= Const.epdTimeout {
            var httpHeaderFields = [String: String]()
            if let lastAsrEventTime = UserDefaults.Nugu.lastAsrEventTime {
                httpHeaderFields["Last-Asr-Event-Time"] = lastAsrEventTime
            }
            upstreamDataSender.sendStream(
                Event(
                    typeInfo: .recognize(initiator: asrRequest.initiator, options: asrRequest.options, service: asrRequest.service),
                    dialogAttributes: dialogAttributeStore.requestAttributes(key: expectSpeech?.messageId),
                    referrerDialogRequestId: asrRequest.referrerDialogRequestId
                ).makeEventMessage(
                    property: self.capabilityAgentProperty,
                    eventIdentifier: asrRequest.eventIdentifier,
                    httpHeaderFields: httpHeaderFields,
                    contextPayload: asrRequest.contextPayload
                )) { [weak self] (state) in
                    self?.asrDispatchQueue.async { [weak self] in
                        guard let self else { return }
                        guard self.asrRequest?.eventIdentifier == asrRequest.eventIdentifier else { return }
                        
                        switch state {
                        case .error(let error):
                            self.asrResult = .error(error)
                        case .sent:
                            UserDefaults.Nugu.lastAsrEventTime = eventTimeFormatter.string(from: Date())
                        case let .received(part):
                            guard part.header.namespace != capabilityAgentProperty.category.name else {
                                asrRequest.completion?(state)
                                return
                            }
                            asrState = .idle
                        default:
                            break
                        }
                        
                        asrRequest.completion?(state)
                    }
                }
        }
        
        asrDispatchQueue.async { [weak self] in
            self?.asrState = .listening(initiator: asrRequest.initiator)
            self?.attachmentSeq = 0
        }
        
        switch asrRequest.options.endPointing {
        case .client:
            // TODO: EPD Engine Injection
            let engine = TycheEndPointDetectorEngineAdapter()
            
            endPointDetector = ClientEndPointDetector(
                asrOptions: asrRequest.options,
                engine: engine
            )
        case .server:
            // TODO: after server preparation.
            log.error("Server side end point detector does not support yet.")
            asrResult = .error(ASRError.listenFailed)
            //            endPointDetector = ServerEndPointDetector(asrOptions: asrRequest.options)
            //
            //            // send wake up voice data
            //            if case let .wakeUpWord(_, data, _, _, _) = asrRequest.options.initiator {
            //                do {
            //                    let speexData = try SpeexEncoder(sampleRate: Int(asrRequest.options.sampleRate), inputType: .linearPcm16).encode(data: data)
            //
            //                    endPointDetectorSpeechDataExtracted(speechData: speexData)
            //                } catch {
            //                    log.error(error)
            //                }
            //            }
        }
        endPointDetector?.delegate = self
        endPointDetector?.start()
    }
    
    /// asrDispatchQueue
    func executeStopSpeech() {
        guard let asrRequest = asrRequest else {
            log.error("ASRRequest not exist")
            asrResult = .cancel()
            return
        }
        switch asrState {
        case .recognizing, .listening:
            break
        case .idle, .expectingSpeech, .busy:
            log.warning("Not permitted in current state \(self.asrState)")
            return
        }
        
        asrState = .busy
        
        let attachment = Attachment(typeInfo: .recognize).makeAttachmentMessage(
            property: self.capabilityAgentProperty,
            dialogRequestId: asrRequest.eventIdentifier.dialogRequestId,
            referrerDialogRequestId: asrRequest.referrerDialogRequestId,
            attachmentSeq: self.attachmentSeq,
            isEnd: true,
            speechData: Data()
        )
        upstreamDataSender.sendStream(attachment)
    }
    
    /// asrDispatchQueue
    func startRecognition(
        initiator: ASRInitiator,
        eventIdentifier: EventIdentifier,
        service: [String: AnyHashable]?,
        options: ASROptions?,
        completion: ((StreamDataState) -> Void)?
    ) {
        let semaphore = DispatchSemaphore(value: 0)
        let asrOptions: ASROptions = if let epd = self.expectSpeech?.payload.epd {
            ASROptions(
                maxDuration: epd.maxDuration ?? options?.maxDuration ?? self.options.maxDuration,
                timeout: epd.timeout ?? options?.timeout ?? self.options.maxDuration,
                pauseLength: epd.pauseLength ?? options?.pauseLength ?? self.options.maxDuration,
                encoding: self.options.encoding,
                endPointing: self.options.endPointing
            )
        } else if let options {
            options
        } else {
            self.options
        }
        asrRequest = ASRRequest(
            eventIdentifier: eventIdentifier,
            initiator: initiator,
            options: asrOptions,
            referrerDialogRequestId: expectSpeech?.dialogRequestId,
            service: service,
            completion: completion
        )
        self.contextManager.getContexts { [weak self] contextPayload in
            defer {
                semaphore.signal()
            }
            
            guard let self = self else { return }
            
            self.asrRequest?.contextPayload = contextPayload
            self.focusManager.requestFocus(channelDelegate: self)
        }
        
        semaphore.wait()
    }
    
    func analyzeBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let int16ChannelData = buffer.int16ChannelData else {
            return
        }
        
        let channelData = int16ChannelData[0]  // 첫 번째 채널 사용
        let frameLength = Int(buffer.frameLength)
        
        // Int16 샘플을 Float로 변환 (정규화)
        var floatSamples = [Float](repeating: 0.0, count: frameLength)
        let scale: Float = 1.0 / 32768.0  // Int16 최대값 기준 정규화

        vDSP_vflt16(channelData, 1, &floatSamples, 1, vDSP_Length(frameLength))  // Int16 -> Float 변환
        vDSP_vsmul(floatSamples, 1, [scale], &floatSamples, 1, vDSP_Length(frameLength))  // 스케일링해서 -1.0 ~ 1.0로 맞추기
        
        // RMS 계산
        var rms: Float = 0.0
        vDSP_rmsqv(floatSamples, 1, &rms, vDSP_Length(frameLength))
        
        post(NuguAgentNotification.ASR.Amplitude(amplitude: rms))
    }
}

// MARK: - Observers

extension Notification.Name {
    static let asrAgentStartRecognition = Notification.Name("com.sktelecom.romaine.notification.name.asr_agent_start_recognition")
    static let asrAgentStateDidChange = Notification.Name("com.sktelecom.romaine.notification.name.asr_agent_state_did_chage")
    static let asrAgentResultDidReceive = Notification.Name("com.sktelecom.romaine.notification.name.asr_agent_result_did_receive")
    static let asrAgentMicBufferAmplitude = Notification.Name("com.sktelecom.romaine.notification.name.asr_agent_mic_buffer_amplitude")
}

public extension NuguAgentNotification {
    enum ASR {
        public struct StartRecognition: TypedNotification {
            public static let name: Notification.Name = .asrAgentStartRecognition
            public let dialogRequestId: String
            
            public static func make(from: [String: Any]) -> StartRecognition? {
                guard let dialogRequestId = from["dialogRequestId"] as? String else { return nil }
                
                return StartRecognition(dialogRequestId: dialogRequestId)
            }
        }
        
        public struct State: TypedNotification {
            public static let name: Notification.Name = .asrAgentStateDidChange
            public let state: ASRState
            
            public static func make(from: [String: Any]) -> State? {
                guard let state = from["state"] as? ASRState else { return nil }
                
                return State(state: state)
            }
        }
        
        public struct Result: TypedNotification {
            public static let name: Notification.Name = .asrAgentResultDidReceive
            public let result: ASRResult
            public let dialogRequestId: String
            
            public static func make(from: [String: Any]) -> Result? {
                guard let result = from["result"] as? ASRResult,
                      let dialogRequestId = from["dialogRequestId"] as? String else { return nil }
                
                return Result(result: result, dialogRequestId: dialogRequestId)
            }
        }
        
        public struct Amplitude: TypedNotification {
            public static let name: Notification.Name = .asrAgentMicBufferAmplitude
            public let amplitude: Float
            
            public static func make(from: [String: Any]) -> Amplitude? {
                guard let amplitude = from["amplitude"] as? Float else { return nil }
                
                return Amplitude(amplitude: amplitude)
            }
        }
    }
}

private extension ASRAgent {
    func addPlaySyncObserver(_ object: PlaySyncManageable) {
        playSyncObserver = object.observe(NuguCoreNotification.PlaySync.ReleasedProperty.self, queue: nil) { [weak self] (notification) in
            self?.asrDispatchQueue.async { [weak self] in
                guard let self = self else { return }
                guard notification.property == self.playSyncProperty, self.expectSpeech?.messageId == notification.messageId else { return }
                
                self.stopRecognition()
            }
        }
    }
}

private enum Const {
    static let epdTimeout: Double = 20.0
}
