//
//  TextAgentRequestType.swift
//  NuguAgents
//
//  Created by yonghoonKwon on 2020/09/02.
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

@available(*, deprecated, message: "It will be removed in 1.9.0")
public enum TextAgentRequestType: Equatable {
    /// send text request only with "text" and "token" infos
    case normal
    /// send text request only with "text", "token", "playServiceId" infos
    case specific(playServiceId: String)
    /// send text request with "text", "token", "playServiceId", "domainTypes", "asrContext" infos
    case dialog
}
