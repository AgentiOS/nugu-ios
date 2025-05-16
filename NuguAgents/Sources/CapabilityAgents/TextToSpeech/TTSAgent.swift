//
//  TTSAgent.swift
//  NuguAgents
//
//  Created by MinChul Lee on 11/04/2019.
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
import NuguUtils

public final class TTSAgent: TTSAgentProtocol {
    // CapabilityAgentable
    public var capabilityAgentProperty: CapabilityAgentProperty = CapabilityAgentProperty(category: .textToSpeech, version: "1.4")
    public weak var delegate: TTSAgentDelegate?
    private let playSyncProperty = PlaySyncProperty(layerType: .info, contextType: .sound)
    
    // TTSAgentProtocol
    public var directiveCancelPolicy: DirectiveCancelPolicy = .cancelNone
    public var offset: Int? {
        ttsDispatchQueue.sync {
            latestPlayer?.offset.truncatedSeconds
        }
    }
    
    public var duration: Int? {
        ttsDispatchQueue.sync {
            latestPlayer?.duration.truncatedSeconds
        }
    }
    
    public var volume: Float = 1.0 {
        didSet {
            ttsDispatchQueue.sync {
                latestPlayer?.volume = volume
            }
        }
    }
    
    public var speed: Float = 1.0 {
        didSet {
            ttsDispatchQueue.sync {
                latestPlayer?.speed = speed
            }
        }
    }
    
    public var gain: Float = .zero
    
    // Private
    private let playSyncManager: PlaySyncManageable
    private let contextManager: ContextManageable
    private let focusManager: FocusManageable
    private let directiveSequencer: DirectiveSequenceable
    private let upstreamDataSender: UpstreamDataSendable
    
    private let ttsNotificationQueue = DispatchQueue(label: "com.sktelecom.romaine.tts_agent_notification_queue")
    private let ttsDispatchQueue = DispatchQueue(label: "com.sktelecom.romaine.tts_agent", qos: .userInitiated)
    
    // Observers
    private let notificationCenter = NotificationCenter.default
    private var playSyncObserver: Any?
    
    private var ttsState: TTSState = .idle {
        didSet {
            log.info("state changed from: \(oldValue) to: \(ttsState)")
            guard let latestPlayer else {
                log.error("TTSPlayer is nil")
                return
            }
            
            // `PlaySyncState` -> `TTSAgentDelegate`
            switch ttsState {
            case .playing:
                if latestPlayer.payload.playServiceId != nil {
                    playSyncManager.startPlay(
                        property: playSyncProperty,
                        info: PlaySyncInfo(
                            playStackServiceId: latestPlayer.payload.playStackControl?.playServiceId,
                            dialogRequestId: latestPlayer.header.dialogRequestId,
                            messageId: latestPlayer.header.messageId,
                            duration: NuguTimeInterval(seconds: 7)
                        )
                    )
                }
            case .finished, .stopped:
                if latestPlayer.payload.playServiceId != nil {
                    if latestPlayer.cancelAssociation {
                        playSyncManager.stopPlay(dialogRequestId: latestPlayer.header.dialogRequestId)
                    } else {
                        playSyncManager.endPlay(property: playSyncProperty)
                    }
                }
            default:
                break
            }
            
            // Notify delegates only if the agent's status changes.
            if oldValue != ttsState {
                let state = ttsState
                ttsNotificationQueue.async { [weak self] in
                    self?.post(NuguAgentNotification.TTS.State(state: state, header: latestPlayer.header))
                }
            }
        }
    }
    
    private let ttsResultSubject = PassthroughSubject<(dialogRequestId: String, result: TTSResult), Never>()
    
    // Players
    private var currentPlayer: TTSPlayer? {
        didSet {
            currentPlayer?.volume = volume
            prefetchPlayer = nil
        }
    }
    private var prefetchPlayer: TTSPlayer? {
        didSet {
            prefetchPlayer?.delegate = self
        }
    }
    private var latestPlayer: TTSPlayer? {
        prefetchPlayer ?? currentPlayer
    }

    private var cancellables = Set<AnyCancellable>()
    
    // Handleable Directives
    private lazy var handleableDirectiveInfos = [
        DirectiveHandleInfo(
            namespace: capabilityAgentProperty.name,
            name: "Speak",
            blockingPolicy: BlockingPolicy(blockedBy: .audio, blocking: .audioOnly),
            preFetch: prefetchPlay,
            cancelDirective: cancelPlay,
            directiveHandler: handlePlay,
            attachmentHandler: handleAttachment
        ),
        DirectiveHandleInfo(
            namespace: capabilityAgentProperty.name,
            name: "Stop",
            blockingPolicy: BlockingPolicy(blockedBy: .any, blocking: nil),
            directiveHandler: handleStop
        )
    ]
    
    public init(
        focusManager: FocusManageable,
        upstreamDataSender: UpstreamDataSendable,
        playSyncManager: PlaySyncManageable,
        contextManager: ContextManageable,
        directiveSequencer: DirectiveSequenceable
    ) {
        self.focusManager = focusManager
        self.upstreamDataSender = upstreamDataSender
        self.playSyncManager = playSyncManager
        self.contextManager = contextManager
        self.directiveSequencer = directiveSequencer
        
        addPlaySyncObserver(playSyncManager)
        contextManager.addProvider(contextInfoProvider)
        focusManager.add(channelDelegate: self)
        directiveSequencer.add(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
    }
    
    deinit {
        if let playSyncObserver = playSyncObserver {
            notificationCenter.removeObserver(playSyncObserver)
        }
        
        contextManager.removeProvider(contextInfoProvider)
        directiveSequencer.remove(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
        currentPlayer?.stop()
        prefetchPlayer?.stop()
    }
    
    public lazy var contextInfoProvider: ContextInfoProviderType = { [weak self] completion in
        guard let self else { return }
        
        let payload: [String: AnyHashable] = [
            "ttsActivity": ttsState.value,
            "version": capabilityAgentProperty.version,
            "engine": "skt",
            "token": currentPlayer?.payload.token,
            "allowSpeak": delegate?.ttsAgentAllowSpeak() ?? false
        ]
        completion(ContextInfo(contextType: .capability, name: capabilityAgentProperty.name, payload: payload.compactMapValues { $0 }))
    }
}

// MARK: - TTSAgentProtocol

public extension TTSAgent {
    func requestTTS(
        text: String,
        playServiceId: String?,
        handler: ((_ ttsResult: TTSResult, _ dialogRequestId: String) -> Void)?
    ) -> String {
        let eventIdentifier = sendCompactContextEvent(
            Event(
                typeInfo: .speechPlay(text: text),
                token: nil,
                playServiceId: playServiceId,
                referrerDialogRequestId: nil
            )
        )
        
        ttsResultSubject
            .filter { $0.dialogRequestId == eventIdentifier.dialogRequestId }
            .prefix(1)
            .sink { dialogRequestId, result in
                handler?(result, dialogRequestId)
            }
            .store(in: &cancellables)
        return eventIdentifier.dialogRequestId
    }
    
    func stopTTS(cancelAssociation: Bool) {
        ttsDispatchQueue.async { [weak self] in
            guard let player = self?.latestPlayer else { return }
            
            self?.stop(player: player, cancelAssociation: cancelAssociation)
        }
    }
    
    func updateLatestPlayerVolume(_ volume: Float) {
        ttsDispatchQueue.sync {
            latestPlayer?.volume = volume
        }
    }
}

// MARK: - FocusChannelDelegate

extension TTSAgent: FocusChannelDelegate {
    public func focusChannelPriority() -> FocusChannelPriority {
        .information
    }
    
    public func focusChannelDidChange(focusState: FocusState) {
        ttsDispatchQueue.async { [weak self] in
            guard let self else { return }
            
            log.info("\(focusState) \(ttsState)")
            switch (focusState, ttsState) {
            case let (.foreground, ttsState) where [.idle, .stopped, .finished].contains(ttsState):
                if let currentPlayer, currentPlayer.internalPlayer != nil {
                    currentPlayer.play()
                } else {
                    log.error("currentPlayer is nil")
                    releaseFocusIfNeeded()
                }
            // Ignore (foreground, playing)
            case (.foreground, _):
                break
            case (.background, _), (.nothing, _):
                if let currentPlayer {
                    stop(player: currentPlayer, cancelAssociation: false)
                }
            // Ignore prepare
            default:
                break
            }
        }
    }
}

// MARK: - MediaPlayerDelegate

extension TTSAgent: MediaPlayerDelegate {
    public func mediaPlayerStateDidChange(_ state: MediaPlayerState, mediaPlayer: MediaPlayable) {
        guard let player = mediaPlayer as? TTSPlayer else { return }
        log.info("media \(mediaPlayer) state: \(state)")
        
        ttsDispatchQueue.async { [weak self] in
            guard let self else { return }
            
            var ttsResult: (dialogRequestId: String, result: TTSResult)?
            var ttsState: TTSState?
            var eventTypeInfo: Event.TypeInfo?
            
            switch state {
            case .start:
                ttsState = .playing
                eventTypeInfo = .speechStarted
            case .resume:
                ttsState = .playing
            case .finish:
                ttsResult = (dialogRequestId: player.header.dialogRequestId, result: .finished)
                ttsState = .finished
                eventTypeInfo = .speechFinished
            case .pause:
                stop(player: player, cancelAssociation: false)
            case .stop:
                ttsResult = (dialogRequestId: player.header.dialogRequestId, result: .stopped(cancelAssociation: player.cancelAssociation))
                ttsState = .stopped
                eventTypeInfo = .speechStopped
            case let .error(error):
                ttsResult = (dialogRequestId: player.header.dialogRequestId, result: .error(error))
                ttsState = .stopped
                eventTypeInfo = .speechStopped
            case .bufferEmpty, .likelyToKeepUp:
                break
            }
            
            // `TTSResult` -> `TTSState` -> `FocusState` -> Event
            if let ttsResult = ttsResult {
                ttsResultSubject.send(ttsResult)
            }
            if let ttsState, latestPlayer === player {
                self.ttsState = ttsState
                switch ttsState {
                case .stopped, .finished:
                    releaseFocusIfNeeded()
                default:
                    break
                }
            }
            if let eventTypeInfo = eventTypeInfo {
                sendCompactContextEvent(
                    Event(
                        typeInfo: eventTypeInfo,
                        token: player.payload.token,
                        playServiceId: player.payload.playServiceId,
                        referrerDialogRequestId: player.header.dialogRequestId
                    )
                )
            }
        }
    }
    
    public func mediaPlayerChunkDidConsume(_ chunk: Data) {
        post(NuguAgentNotification.TTS.Chunk(chunk: chunk))
    }
    
    public func mediaPlayerDurationDidChange(_ duration: TimeIntervallic, mediaPlayer: MediaPlayable) {
        post(NuguAgentNotification.TTS.Duration(duration: duration.truncatedMilliSeconds))
    }
}

// MARK: - Private (Directive)

private extension TTSAgent {
    func prefetchPlay() -> PrefetchDirective {
        return { [weak self] directive in
            guard let self else { return }
            let player = try TTSPlayer(directive: directive, gain: gain)
            player.speed = speed
            
            ttsDispatchQueue.sync { [weak self] in
                guard let self else { return }
                
                log.debug(directive.header.messageId)
                if prefetchPlayer?.stop(reason: .playAnother) == true
                    || currentPlayer?.stop(reason: .playAnother) == true {
                    ttsState = .stopped
                }
                
                prefetchPlayer = player
                focusManager.prepareFocus(channelDelegate: self)
            }
        }
    }
    
    func cancelPlay() -> CancelDirective {
        return { [weak self] directive in
            self?.ttsDispatchQueue.sync { [weak self] in
                guard let self else { return }
                guard prefetchPlayer?.header.messageId == directive.header.messageId else {
                    log.info("Message id does not match")
                    return
                }
                
                prefetchPlayer = nil
                focusManager.cancelFocus(channelDelegate: self)
            }
        }
    }
    
    func handlePlay() -> HandleDirective {
        return { [weak self] directive, completion in
            self?.ttsDispatchQueue.async { [weak self] in
                guard let self else {
                    completion(.canceled)
                    return
                }
                guard let prefetchPlayer, prefetchPlayer.header.messageId == directive.header.messageId else {
                    completion(.canceled)
                    log.info("Message id does not match")
                    return
                }
                guard prefetchPlayer.internalPlayer != nil else {
                    completion(.canceled)
                    log.info("Internal player is nil")
                    return
                }
                
                log.debug(directive.header.messageId)
                currentPlayer = prefetchPlayer
                
                ttsNotificationQueue.async { [weak self] in
                    self?.post(NuguAgentNotification.TTS.Result(text: prefetchPlayer.payload.text, header: prefetchPlayer.header))
                }
                
                ttsResultSubject
                    .filter { $0.dialogRequestId == prefetchPlayer.header.dialogRequestId }
                    .prefix(1)
                    .sink { [weak self] _, result in
                        guard let self = self else {
                            completion(.canceled)
                            return
                        }
                        switch result {
                        case .finished:
                            completion(.finished)
                        case .stopped(let cancelAssociation):
                            if cancelAssociation {
                                completion(.stopped(directiveCancelPolicy: .cancelAll))
                            } else {
                                completion(.stopped(directiveCancelPolicy: directiveCancelPolicy))
                            }
                        case .error(let error):
                            completion(.failed("\(error)"))
                        }
                    }
                    .store(in: &cancellables)
            }
        }
    }
    
    func handleStop() -> HandleDirective {
        return { [weak self] _, completion in
            defer { completion(.finished) }
            
            self?.ttsDispatchQueue.async { [weak self] in
                guard let self, let currentPlayer else { return }
                guard currentPlayer.internalPlayer != nil else {
                    // Release synchronized layer after playback finished.
                    if currentPlayer.payload.playServiceId != nil {
                        playSyncManager.stopPlay(dialogRequestId: currentPlayer.header.dialogRequestId)
                    }
                    return
                }
                
                stop(player: currentPlayer, cancelAssociation: true)
            }
        }
    }
    
    func stop(player: TTSPlayer, cancelAssociation: Bool) {
        player.cancelAssociation = cancelAssociation
        player.stop()
        directiveSequencer.cancelDirective(dialogRequestId: player.header.dialogRequestId)
    }
    
    func handleAttachment() -> HandleAttachment {
        #if DEBUG
        var totalAttachmentData = Data()
        #endif
        
        return { [weak self] attachment in
            self?.ttsDispatchQueue.async { [weak self] in
                log.info("\(attachment)")
                guard let self else { return }
                guard prefetchPlayer?.handleAttachment(attachment) == true
                        || currentPlayer?.handleAttachment(attachment) == true else {
                    log.warning("MediaOpusStreamDataSource not exist or dialogRequesetId not valid")
                    return
                }
                
                focusManager.requestFocus(channelDelegate: self)
            }
            
            #if DEBUG
            totalAttachmentData.append(attachment.content)
            if attachment.isEnd {
                let attachmentFileName = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("attachment.data")
                try? totalAttachmentData.write(to: attachmentFileName)
                log.debug("attachment to file :\(attachmentFileName)")
            }
            #endif
        }
    }
}

// MARK: - Private (Event)

private extension TTSAgent {
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

// MARK: - Private(FocusManager)

private extension TTSAgent {
    func releaseFocusIfNeeded() {
        guard [.idle, .stopped, .finished].contains(ttsState) else {
            log.info("Not permitted in current state, \(ttsState)")
            return
        }
        focusManager.releaseFocus(channelDelegate: self)
    }
}

// MARK: - Observer

extension Notification.Name {
    static let ttsAgentStateDidChange = Notification.Name(rawValue: "com.sktelecom.romaine.notification.name.tts_agent_state_did_change")
    static let ttsAgentResultDidReceive = Notification.Name(rawValue: "com.sktelecom.romaine.notification.name.tts_agent_result_did_receive")
    static let ttsAgentChunkDidConsumed = Notification.Name(rawValue: "com.sktelecom.romaine.notification.name.tts_agent_chunk_did_consumed")
    static let ttsAgentDurationDidComputed = Notification.Name(rawValue: "com.sktelecom.romaine.notification.name.tts_agent_duration_did_computed")
}

public extension NuguAgentNotification {
    enum TTS {
        public struct State: TypedNotification {
            public static var name: Notification.Name = .ttsAgentStateDidChange
            public let state: TTSState
            public let header: Downstream.Header
            
            public static func make(from: [String: Any]) -> State? {
                guard let state = from["state"] as? TTSState,
                      let header = from["header"] as? Downstream.Header else { return nil }
                
                return State(state: state, header: header)
            }
        }
            
        public struct Result: TypedNotification {
            public static var name: Notification.Name = .ttsAgentResultDidReceive
            public let text: String?
            public let header: Downstream.Header
            
            public static func make(from: [String: Any]) -> Result? {
                guard let text = from["text"] as? String,
                      let header = from["header"] as? Downstream.Header else { return nil }
                
                return Result(text: text, header: header)
            }
        }
        
        public struct Chunk: TypedNotification {
            public static var name: Notification.Name = .ttsAgentChunkDidConsumed
            public let chunk: Data
            
            public static func make(from: [String: Any]) -> Chunk? {
                guard let chunk = from["chunk"] as? Data else { return nil }
                return Chunk(chunk: chunk)
            }
        }
        
        public struct Duration: TypedNotification {
            public static var name: Notification.Name = .ttsAgentDurationDidComputed
            public let duration: Int
            
            public static func make(from: [String: Any]) -> NuguAgentNotification.TTS.Duration? {
                guard let duration = from["duration"] as? Int else { return nil }
                return Duration(duration: duration)
            }
        }
    }

}

private extension TTSAgent {
    func addPlaySyncObserver(_ object: PlaySyncManageable) {
        playSyncObserver = object.observe(NuguCoreNotification.PlaySync.ReleasedProperty.self, queue: nil) { [weak self] (notification) in
            self?.ttsDispatchQueue.async { [weak self] in
                guard let self else { return }
                guard notification.property == playSyncProperty,
                      let latestPlayer,
                      latestPlayer.header.messageId == notification.messageId else { return }
                
                stop(player: latestPlayer, cancelAssociation: true)
            }
        }
    }
}
