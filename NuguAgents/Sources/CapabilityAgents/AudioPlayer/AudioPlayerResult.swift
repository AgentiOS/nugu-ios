//
//  AudioPlayerResult.swift
//  
//
//  Created by childc on 2022/12/12.
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

/// A result of AudioPlayer request.
public enum AudioPlayerResult {
    /// Indicates that playback has finished.
    case finished
    /// Indicates that audio playback was stopped due to a user request or a directive which stops or replaces the current stream.
    case stopped
    /// Indicates that audio playback was stopped due to an error.
    case error(_ error: Error)
}
