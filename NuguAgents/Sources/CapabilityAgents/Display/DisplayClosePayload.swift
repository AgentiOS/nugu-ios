//
//  DisplayClosePayload.swift
//  NuguAgents
//
//  Created by MinChul Lee on 2020/01/10.
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

struct DisplayClosePayload {
    let playServiceId: String
    let service: [String: AnyHashable]?
}

// MARK: - Decodable

extension DisplayClosePayload: Decodable {
    enum CodingKeys: String, CodingKey {
        case playServiceId
        case service
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        playServiceId = try container.decode(String.self, forKey: .playServiceId)
        service = try container.decodeIfPresent([String: AnyHashable].self, forKey: .service)
    }
}
