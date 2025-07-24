//
//  TycheEndPointDetectorEngineAdapter.swift
//  nugu-ios
//
//  Created by 김승찬님/iOS개발팀 on 4/21/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
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

import JadeMarble

public class TycheEndPointDetectorEngineAdapter: EndPointDetectorEngineProtocol {
    private let engine: TycheEndPointDetectorEngine
    
    public weak var delegate: EndPointDetectorEngineDelegate?
    public var flushTime: Int
    
    public var state: EndPointDetectorEngineState {
        return engineState(from: engine.state)
    }
    
    init() {
        self.engine = TycheEndPointDetectorEngine()
        self.flushTime = engine.flushTime
        engine.delegate = self
    }
    
    public func start(
        sampleRate: Double,
        timeout: Int,
        maxDuration: Int,
        pauseLength: Int
    ) {
        engine.start(
            sampleRate: sampleRate,
            timeout: timeout,
            maxDuration: maxDuration,
            pauseLength: pauseLength
        )
    }
    
    public func putAudioBuffer(buffer: AVAudioPCMBuffer) {
        engine.putAudioBuffer(buffer: buffer)
    }
    
    public func stop() {
        engine.stop()
    }
    
    public func resetEPDTimeout() -> Bool {
        engine.resetEPDTimeout()
    }
    
    private func engineState(from tycheState: TycheEndPointDetectorEngine.State) -> EndPointDetectorEngineState {
        switch tycheState {
        case .idle:
            return .idle
        case .listening:
            return .listening
        case .start:
            return .start
        case .end:
            return .end
        case .timeout:
            return .timeout
        case .reachToMaxLength:
            return .reachToMaxLength
        case .finish:
            return .finish
        case .unknown:
            return .unknown
        case .error:
            return .error
        }
    }
}

extension TycheEndPointDetectorEngineAdapter: TycheEndPointDetectorEngineDelegate {
    public func tycheEndPointDetectorEngineDidChange(state: TycheEndPointDetectorEngine.State) {
        delegate?.endPointDetectorEngineDidChange(state: engineState(from: state))
    }
    
    public func tycheEndPointDetectorEngineDidExtract(speechData: Data) {
        delegate?.endPointDetectorEngineDidExtract(speechData: speechData)
    }
}
