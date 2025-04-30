//
//  DisplayControlPayload.swift
//  NuguAgents
//
//  Created by jin kim on 2020/01/29.
//  Copyright © 2020 SK Telecom Co., Ltd. All rights reserved.
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

/// <#Description#>
public struct DisplayControlPayload {
    /// <#Description#>
    let playServiceId: String
    /// <#Description#>
    let direction: Direction
    let interactionControl: InteractionControl?
    let service: [String: AnyHashable]?
    
    /// <#Description#>
    public enum Direction: String, Codable {
        case previous = "PREVIOUS"
        case next = "NEXT"
    }
}

// MARK: - Codable

extension DisplayControlPayload: Codable {
    enum CodingKeys: String, CodingKey {
        case playServiceId
        case direction
        case interactionControl
        case service
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        playServiceId = try container.decode(String.self, forKey: .playServiceId)
        direction = try container.decode(Direction.self, forKey: .direction)
        interactionControl = try? container.decode(InteractionControl.self, forKey: .interactionControl)
        service = try container.decodeIfPresent([String: AnyHashable].self, forKey: .service)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(playServiceId, forKey: .playServiceId)
        try container.encode(direction, forKey: .direction)
        try container.encode(interactionControl, forKey: .interactionControl)
        try container.encodeIfPresent(service, forKey: .service)
    }
}
