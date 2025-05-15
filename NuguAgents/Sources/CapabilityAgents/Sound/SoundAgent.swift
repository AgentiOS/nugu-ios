//
//  SoundAgent.swift
//  NuguAgents
//
//  Created by MinChul Lee on 2020/04/07.
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

public final class SoundAgent: SoundAgentProtocol {
    // CapabilityAgentable
    public var capabilityAgentProperty: CapabilityAgentProperty = CapabilityAgentProperty(category: .sound, version: "1.0")
    
    // SoundAgentProtocol
    public weak var dataSource: SoundAgentDataSource?
    public var volume: Float = 1.0 {
        didSet {
            currentPlayer?.volume = volume
        }
    }
    
    // Private
    private let contextManager: ContextManageable
    private let focusManager: FocusManageable
    private let directiveSequencer: DirectiveSequenceable
    private let upstreamDataSender: UpstreamDataSendable
    
    private let soundDispatchQueue = DispatchQueue(label: "com.sktelecom.romaine.sound_agent", qos: .userInitiated)
    
    private var soundState: SoundState = .idle {
        didSet {
            log.info("state changed from: \(oldValue) to: \(soundState)")
            guard let media = currentMedia else {
                log.error("SoundMedia is nil")
                return
            }
            
            // Release focus
            switch soundState {
            case .idle, .finished, .stopped:
                releaseFocusIfNeeded()
            case .playing:
                break
            }
            
            // Notify delegates only if the agent's status changes.
            if oldValue != soundState {
                post(NuguAgentNotification.Sound.State(state: soundState, header: media.header))
            }
        }
    }
    private var currentMedia: SoundMedia?
    private var currentPlayer: MediaPlayable?
    
    // Handleable Directives
    private lazy var handleableDirectiveInfos = [
        DirectiveHandleInfo(namespace: capabilityAgentProperty.name, name: "Beep", blockingPolicy: BlockingPolicy(blockedBy: .audio, blocking: .audioOnly), preFetch: prefetchBeep, directiveHandler: handleBeep)
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        focusManager: FocusManageable,
        upstreamDataSender: UpstreamDataSendable,
        contextManager: ContextManageable,
        directiveSequencer: DirectiveSequenceable
    ) {
        self.focusManager = focusManager
        self.upstreamDataSender = upstreamDataSender
        self.contextManager = contextManager
        self.directiveSequencer = directiveSequencer
        
        contextManager.addProvider(contextInfoProvider)
        focusManager.add(channelDelegate: self)
        directiveSequencer.add(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
    }
    
    deinit {
        contextManager.removeProvider(contextInfoProvider)
        directiveSequencer.remove(directiveHandleInfos: handleableDirectiveInfos.asDictionary)
        currentPlayer?.stop()
    }
    
    public lazy var contextInfoProvider: ContextInfoProviderType = { [weak self] completion in
        guard let self else { return }
        
        let payload: [String: AnyHashable] = ["version": capabilityAgentProperty.version]
        completion(ContextInfo(contextType: .capability, name: capabilityAgentProperty.name, payload: payload))
    }
}

// MARK: - FocusChannelDelegate

extension SoundAgent: FocusChannelDelegate {
    public func focusChannelPriority() -> FocusChannelPriority {
        .sound
    }
    
    public func focusChannelDidChange(focusState: FocusState) {
        soundDispatchQueue.async { [weak self] in
            guard let self else { return }

            log.info("\(focusState) \(soundState)")
            switch (focusState, soundState) {
            case (.foreground, let soundState) where [.idle, .stopped, .finished].contains(soundState):
                currentPlayer?.play()
            // Ignore (Foreground, playing)
            case (.foreground, _):
                break
            case (.background, .playing):
                stop()
            // Ignore (background, [idle, stopped, finished])
            case (.background, _):
                break
            case (.nothing, .playing):
                stop()
            // Ignore (prepare, _) and (none, [idle/stopped/finished])
            default:
                break
            }
        }
    }
}

// MARK: - MediaPlayerDelegate

extension SoundAgent: MediaPlayerDelegate {
    public func mediaPlayerStateDidChange(_ state: MediaPlayerState, mediaPlayer: MediaPlayable) {
        log.info("media state: \(state)")
        
        soundDispatchQueue.async { [weak self] in
            guard let self else { return }
            // `SoundState` -> `FocusState`
            switch state {
            case .start, .resume:
                soundState = .playing
            case .finish:
                soundState = .finished
            case .pause:
                stop()
            case .stop:
                soundState = .stopped
            case .bufferEmpty, .likelyToKeepUp:
                break
            case .error:
                soundState = .stopped
            }
        }
    }
}

// MARK: - Private (Directive)

private extension SoundAgent {
    func prefetchBeep() -> PrefetchDirective {
        return { [weak self] directive in
            guard let self else { return }
            let payload = try JSONDecoder().decode(SoundMedia.Payload.self, from: directive.payload)
            
            soundDispatchQueue.async { [weak self] in
                guard let self else { return }
                guard let url = dataSource?.soundAgentRequestUrl(beepName: payload.beepName, header: directive.header) else {
                    sendCompactContextEvent(
                        Event(
                            typeInfo: .beepFailed,
                            playServiceId: payload.playServiceId,
                            referrerDialogRequestId: directive.header.dialogRequestId
                        )
                    )
                    return
                }
                stopSilently()
                
                let mediaPlayer = MediaPlayer()
                mediaPlayer.setSource(url: url)
                mediaPlayer.delegate = self
                mediaPlayer.volume = volume
                
                currentPlayer = mediaPlayer
                currentMedia = SoundMedia(
                    payload: payload,
                    header: directive.header
                )
                sendCompactContextEvent(
                    Event(
                        typeInfo: .beepSucceeded,
                        playServiceId: payload.playServiceId,
                        referrerDialogRequestId: directive.header.dialogRequestId
                    )
                )
            }
        }
    }
    
    func handleBeep() -> HandleDirective {
        return { [weak self] directive, completion in
            defer { completion(.finished) }
            
            self?.soundDispatchQueue.async { [weak self] in
                guard let self else { return }
                guard currentMedia?.header.messageId == directive.header.messageId else {
                    log.info("Message id does not match")
                    return
                }
                
                focusManager.requestFocus(channelDelegate: self)
            }
        }
    }
}

// MARK: - Private (MediaPlayer)

private extension SoundAgent {
    func stop() {
        soundDispatchQueue.precondition(.onQueue)
        currentPlayer?.stop()
    }
    
    /// Synchronously stop previously playing beep
    func stopSilently() {
        soundDispatchQueue.precondition(.onQueue)
        guard let currentPlayer else { return }
        
        // `MediaPlayer` -> `SoundState`
        currentPlayer.delegate = nil
        currentPlayer.stop()
        soundState = .stopped
    }
}

// MARK: - Private (Event)

private extension SoundAgent {
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

private extension SoundAgent {
    func releaseFocusIfNeeded() {
        guard [.idle, .stopped, .finished].contains(soundState) else {
            log.info("Not permitted in current state, \(soundState)")
            return
        }
        focusManager.releaseFocus(channelDelegate: self)
    }
}

// MARK: - Observer

extension Notification.Name {
    static let soundAgentDidChange = Notification.Name("com.sktelecom.romain.notification.name.sound_agent_did_change")
}

public extension NuguAgentNotification {
    enum Sound {
        public struct State: TypedNotification {
            public static let name: Notification.Name = .soundAgentDidChange
            public let state: SoundState
            public let header: Downstream.Header

            public static func make(from: [String: Any]) -> State? {
                guard let state = from["state"] as? SoundState,
                      let header = from["header"] as? Downstream.Header else { return nil }
                
                return State(state: state, header: header)
            }
        }
    }
}
