//
//  TTSSpeakPayload.swift
//  NuguAgents
//
//  Created by MinChul Lee on 02/05/2019.
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

import NuguCore

struct TTSSpeakPayload {
    let playStackControl: PlayStackControl?
    let sourceType: SourceType
    let text: String?
    let token: String?
    let playServiceId: String?
    let url: String?
    
    enum SourceType: String, Decodable {
        case url = "URL"
        case attachment = "ATTACHMENT"
    }
}

// MARK: - TTSSpeakPayload: Decodable

extension TTSSpeakPayload: Decodable {
    enum CodingKeys: String, CodingKey {
        case playStackControl
        case sourceType
        case text
        case token
        case playServiceId
        case url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        playStackControl = try? container.decode(PlayStackControl.self, forKey: .playStackControl)
        sourceType = try container.decodeIfPresent(SourceType.self, forKey: .sourceType) ?? .attachment
        text = try? container.decode(String.self, forKey: .text)
        token = try? container.decode(String.self, forKey: .token)
        playServiceId = try? container.decode(String.self, forKey: .playServiceId)
        url = try? container.decode(String.self, forKey: .url)
    }
}
