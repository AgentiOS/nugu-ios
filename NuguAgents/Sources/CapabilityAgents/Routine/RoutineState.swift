//
//  RoutineState.swift
//  NuguAgents
//
//  Created by MinChul Lee on 2020/07/08.
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

public enum RoutineState: Equatable {
    case idle
    case playing
    case interrupted
    case finished
    case stopped
    case suspended
}

public extension RoutineState {
    var routineActivity: String {
        switch self {
        case .idle: return "IDLE"
        case .playing: return "PLAYING"
        case .interrupted: return "INTERRUPTED"
        case .finished: return "FINISHED"
        case .stopped: return "STOPPED"
        case .suspended: return "SUSPENDED"
        }
    }
    
    var isPlaying: Bool {
        [.playing, .suspended].contains(self)
    }
}
