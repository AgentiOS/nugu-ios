//
//  AudioSessionManager.swift
//  NuguClientKit
//
//  Created by 김진님/AI Assistant개발 Cell on 2021/01/07.
//  Copyright © 2021 SK Telecom Co., Ltd. All rights reserved.
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

import AVFoundation

import NuguAgents

final public class AudioSessionManager: AudioSessionManageable {
    public weak var delegate: AudioSessionManagerDelegate?
    private let audioPlayerAgent: AudioPlayerAgentProtocol
    private let defaultCategoryOptions = AVAudioSession.CategoryOptions(arrayLiteral: [.defaultToSpeaker, .allowBluetoothA2DP])
    
    // observers
    private let notificationCenter = NotificationCenter.default
    private var audioSessionInterruptionObserver: Any?
    private var audioSessionRouteObserver: Any?
    private var audioPlayerStateObserver: Any?
    
    /// Initialize
    /// - Parameters:
    ///   - nuguClient: NuguClient instance which should be passed for delegation.
    public init(audioPlayerAgent: AudioPlayerAgentProtocol) {
        self.audioPlayerAgent = audioPlayerAgent
        
        // observers
        addAudioPlayerAgentObserver(audioPlayerAgent)
        addAudioSessionObservers()
        
        // When no other audio is playing, audio session can not detect car play connectivity status even if car play has been already connected.
        // To resolve this problem, activating audio session should be done in prior to detecting car play connectivity.
        if AVAudioSession.sharedInstance().isOtherAudioPlaying == false {
            try? activeAudioSessionIfNeeded()
        }
    }
    
    deinit {
        disable()
    }
    
    public func enable() {
        addAudioPlayerAgentObserver(audioPlayerAgent)
        addAudioSessionObservers()
    }
    
    public func disable() {
        removeAudioPlayerAgentObserver()
        removeAudioSessionObservers()
    }
    
}

// MARK: - Public

public extension AudioSessionManager {
    func isCarplayConnected() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains(where: { $0.portType == .carAudio })
    }
    
    func requestRecordPermission(_ response: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission(response)
    }
    
    @discardableResult func updateAudioSessionToPlaybackIfNeeded(mixWithOthers: Bool = false) -> Bool {
        var options = AVAudioSession.CategoryOptions(arrayLiteral: [])
        if mixWithOthers == true {
            options.insert(.mixWithOthers)
        }
        // If audioSession is already has been set properly, resetting audioSession is unnecessary
        guard isCarplayConnected() == true,
              AVAudioSession.sharedInstance().category != .playback ||
              AVAudioSession.sharedInstance().categoryOptions != options else { return true }
        do {
            try setAudioCategoryIfNeeded(.playback, options: options)
            try activeAudioSessionIfNeeded()
            return true
        } catch {
            log.debug("updateAudioSessionToPlaybackIfNeeded failed: \(error)")
            return false
        }
    }
    
    @discardableResult func updateAudioSessionWhenCarplayConnected(requestingFocus: Bool) -> Bool {
        if requestingFocus {
            let options = AVAudioSession.CategoryOptions(arrayLiteral: [])
            // If audioSession is already has been set properly, resetting audioSession is unnecessary
            guard AVAudioSession.sharedInstance().category != .playAndRecord ||
                  AVAudioSession.sharedInstance().categoryOptions != options else {
                return true
            }
            do {
                try setAudioCategoryIfNeeded(.playAndRecord, options: [])
                try activeAudioSessionIfNeeded()
                return true
            } catch {
                log.debug("updateAudioSession when carplay connected has failed: \(error)")
                return false
            }
        } else {
            return updateAudioSessionToPlaybackIfNeeded(mixWithOthers: true)
        }
    }
    
    /// Update AudioSession.Category and AudioSession.CategoryOptions
    /// - Parameter requestingFocus: whether updating AudioSession is for requesting focus or just updating without requesting focus
    @discardableResult func updateAudioSession(requestingFocus: Bool = false) -> Bool {
        guard isCarplayConnected() == false else {
            return updateAudioSessionWhenCarplayConnected(requestingFocus: requestingFocus)
        }
        
        var options = defaultCategoryOptions
        if requestingFocus == false {
            options.insert(.mixWithOthers)
        }
        
        log.debug("try to set audio session category from: \(AVAudioSession.sharedInstance().category) to: \(AVAudioSession.Category.playAndRecord)")
        log.debug("try to set audio session options from: \(AVAudioSession.sharedInstance().categoryOptions) to: \(options)")
        
        // If audioSession is already has been set properly, resetting audioSession is unnecessary
        guard AVAudioSession.sharedInstance().category != .playAndRecord || AVAudioSession.sharedInstance().categoryOptions != options else {
            log.debug("audio session and options are set already")
            return true
        }
        
        do {
            try setAudioCategoryIfNeeded(.playAndRecord, options: options)
            try activeAudioSessionIfNeeded()
            
            return true
        } catch {
            log.debug("updateAudioSessionCategoryOptions failed: \(error)")
            return false
        }
    }
    
    func notifyAudioSessionDeactivation() {
        log.debug("")
        // Defer statement for recovering audioSession and MicInputProvider
        defer {
            delegate?.audioSessionDidDeactivate()
        }
        do {
            // Clean up all I/O before deactivating audioSession
            delegate?.audioSessionWillDeactivate()
            
            // Notify audio session deactivation to 3rd party apps
            try deactiveAudioSessionIfNeeded()
        } catch {
            log.debug("notifyOthersOnDeactivation failed: \(error)")
        }
    }
}

// MARK: - private (AudioSessionObserver)

private extension AudioSessionManager {
    func addAudioSessionObservers() {
        removeAudioSessionObservers()
        
        audioSessionInterruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil, using: { [weak self] (notification) in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            switch type {
            case .began:
                log.debug("Interruption began")
                // Interruption began, take appropriate actions
                self?.delegate?.audioSessionInterrupted(type: .began)
            case .ended:
                log.debug("Interruption ended")
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    self?.delegate?.audioSessionInterrupted(type: .ended(options: options))
                }
            @unknown default: break
            }
        })
        
        audioSessionRouteObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil, using: { [weak self] (notification) in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
            }
            
            switch reason {
            case .oldDeviceUnavailable:
                let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
                if previousRoute?.outputs.first?.portType == .carAudio {
                    self?.updateAudioSession()
                }
                
                self?.delegate?.audioSessionRouteChanged(reason: .oldDeviceUnavailable(previousRoute: previousRoute))
            case .newDeviceAvailable:
                self?.delegate?.audioSessionRouteChanged(reason: .newDeviceAvailable)
                
                if self?.isCarplayConnected() == true {
                    self?.updateAudioSession()
                }
                
                if self?.audioPlayerAgent.isPlaying == true {
                    self?.updateAudioSessionToPlaybackIfNeeded()
                }
            case .categoryChange, .routeConfigurationChange:
                self?.delegate?.audioSessionRouteChanged(reason: .categoryChange)
            default: break
            }
        })
    }
    
    func removeAudioSessionObservers() {
        if let audioSessionInterruptionObserver = audioSessionInterruptionObserver {
            NotificationCenter.default.removeObserver(audioSessionInterruptionObserver)
            self.audioSessionInterruptionObserver = nil
        }
        
        if let audioRouteObserver = audioSessionRouteObserver {
            NotificationCenter.default.removeObserver(audioRouteObserver)
            self.audioSessionRouteObserver = nil
        }
    }
}

// MARK: - Private (audioPlayerStateObserver)

private extension AudioSessionManager {
    func addAudioPlayerAgentObserver(_ object: AudioPlayerAgentProtocol) {
        audioPlayerStateObserver = object.observe(NuguAgentNotification.AudioPlayer.State.self, queue: .main) { [weak self] (notification) in
            guard let self = self else { return }
            
            if notification.state == .playing && self.isCarplayConnected() == true {
                self.updateAudioSessionToPlaybackIfNeeded()
            }
        }
    }
    
    func removeAudioPlayerAgentObserver() {
        if let audioPlayerStateObserver = audioPlayerStateObserver {
            notificationCenter.removeObserver(audioPlayerStateObserver)
        }
        
        audioPlayerStateObserver = nil
    }
}

// MARK: - Private (audioSessiontActive)

private extension AudioSessionManager {
    func activeAudioSessionIfNeeded() throws {
        guard delegate?.allowsUpdateAudioSessionActivation == true else { return }
        
        try AVAudioSession.sharedInstance().setActive(true)
        
        log.debug("audio session activated")
    }
    
    func deactiveAudioSessionIfNeeded() throws {
        guard delegate?.allowsUpdateAudioSessionActivation == true else { return }
        
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        log.debug("audio session deactivated")
    }
    
    func setAudioCategoryIfNeeded(_ category: AVAudioSession.Category, options: AVAudioSession.CategoryOptions) throws {
        guard delegate?.allowsUpdateAudioSessionActivation == true else { return }
        
        // Client에서 playAndRecord + voiceChat 을 사용하려고 할 때
        let mode: AVAudioSession.Mode = category == .playAndRecord ? AVAudioSession.sharedInstance().mode : .default
        try AVAudioSession.sharedInstance().setCategory(
            category,
            mode: mode,
            options: options
        )
        
        log.debug("set audio session: \(category), options: \(options)")
    }
}

public extension AudioSessionManager {
    enum AudioSessionInterruptionType {
        case began
        case ended(options: AVAudioSession.InterruptionOptions)
    }
    
    enum AudioSessionRouteChangeReason {
        case newDeviceAvailable
        case oldDeviceUnavailable(previousRoute: AVAudioSessionRouteDescription?)
        case categoryChange
    }
}
