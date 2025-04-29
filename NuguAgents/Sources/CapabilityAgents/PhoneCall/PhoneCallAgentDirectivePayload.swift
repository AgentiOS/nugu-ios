//
//  PhoneCallAgentDirectivePayload.swift
//  NuguAgents
//
//  Created by yonghoonKwon on 2021/03/15.
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

public enum PhoneCallAgentDirectivePayload {
    
    /// An Item received through the 'SendCandidates' directive in `PhoneCallAgent`.
    public struct SendCandidates {
        /// The unique identifier to specify play service.
        public let playServiceId: String
        /// The intent of candidates in `PhoneCallAgent`
        public let intent: PhoneCallIntent
        /// Types of phone-call
        public let callType: PhoneCallType?
        /// Recipient information analyzed from utterance
        public let recipientIntended: PhoneCallRecipientIntended?
        /// The candidate searched for play service.
        ///
        /// If nil, there are no search results.
        public var candidates: [PhoneCallPerson]?
        /// The scene of search target and display tempate
        public let searchScene: String?
        /// <#Description#>
        public let interactionControl: InteractionControl?
        public let service: [String: AnyHashable]?
    }
    
    /// An Item received through the 'MakeCall' directive in `PhoneCallAgent`.
    public struct MakeCall {
        /// The unique identifier to specify play service.
        public let playServiceId: String
        /// <#Description#>
        public let recipient: PhoneCallPerson
        /// <#Description#>
        public let callType: PhoneCallType
        public let service: [String: AnyHashable]?
    }
    
    /// An Item received through the 'BlockNumber' directive in `PhoneCallAgent`.
    public struct BlockNumber {
        public enum BlockType: String, Codable {
            case exact = "EXACT"
            case prefix = "PREFIX"
            case postfix = "POSTFIX"
        }
        
        /// The unique identifier to specify play service.
        public let playServiceId: String
        /// <#Description#>
        public let number: String
        /// <#Description#>
        public let blockType: BlockType
    }
}

// MARK: - PhoneCallAgentDirectivePayload.SendCandidates + Codable

extension PhoneCallAgentDirectivePayload.SendCandidates: Codable {
    enum CodingKeys: String, CodingKey {
        case playServiceId
        case intent
        case callType
        case recipientIntended
        case candidates
        case searchScene
        case interactionControl
        case service
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        playServiceId = try container.decode(String.self, forKey: .playServiceId)
        intent = try container.decode(PhoneCallIntent.self, forKey: .intent)
        callType = try container.decodeIfPresent(PhoneCallType.self, forKey: .callType)
        recipientIntended = try container.decodeIfPresent(PhoneCallRecipientIntended.self, forKey: .recipientIntended)
        candidates = try container.decodeIfPresent([PhoneCallPerson].self, forKey: .candidates)
        searchScene = try container.decodeIfPresent(String.self, forKey: .searchScene)
        interactionControl = try container.decodeIfPresent(InteractionControl.self, forKey: .interactionControl)
        service = try container.decodeIfPresent([String: AnyHashable].self, forKey: .service)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(playServiceId, forKey: .playServiceId)
        try container.encode(intent, forKey: .intent)
        try container.encodeIfPresent(callType, forKey: .callType)
        try container.encodeIfPresent(recipientIntended, forKey: .recipientIntended)
        try container.encodeIfPresent(candidates, forKey: .candidates)
        try container.encodeIfPresent(searchScene, forKey: .searchScene)
        try container.encodeIfPresent(interactionControl, forKey: .interactionControl)
        try container.encodeIfPresent(service, forKey: .service)
    }
}

// MARK: - PhoneCallAgentDirectivePayload.MakeCall + Codable

extension PhoneCallAgentDirectivePayload.MakeCall: Codable {
    enum CodingKeys: String, CodingKey {
        case playServiceId
        case recipient
        case callType
        case service
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        playServiceId = try container.decode(String.self, forKey: .playServiceId)
        recipient = try container.decode(PhoneCallPerson.self, forKey: .recipient)
        callType = try container.decode(PhoneCallType.self, forKey: .callType)
        service = try container.decodeIfPresent([String: AnyHashable].self, forKey: .service)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(playServiceId, forKey: .playServiceId)
        try container.encode(recipient, forKey: .recipient)
        try container.encodeIfPresent(callType, forKey: .callType)
        try container.encodeIfPresent(service, forKey: .service)
    }
}

// MARK: - PhoneCallAgentDirectivePayload.BlockNumber + Codable

extension PhoneCallAgentDirectivePayload.BlockNumber: Codable {}
