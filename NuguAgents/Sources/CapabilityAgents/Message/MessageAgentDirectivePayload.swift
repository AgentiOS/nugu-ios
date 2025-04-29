//
//  MessageAgentDirectivePayload.swift
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

/// <#Description#>
public enum MessageAgentDirectivePayload {
    /// An Item received through the 'SendCandidates' directive in `MessageAgent`.
    public struct SendCandidates {
        /// The unique identifier to specify play service.
        public let playServiceId: String
        /// The intent of candidates in `MessageAgent`.
        public let intent: String?
        /// Recipient information analyzed from utterance.
        public let recipientIntended: MessageRecipientIntended?
        /// The scene of search target and display tempate.
        public let searchScene: String?
        /// The candidate searched for play service.
        ///
        /// If nil, there are no search results.
        public let candidates: [MessageAgentContact]?
        /// The message to be used for outgoing.
        public let messageToSend: MessageToSendItem?
        /// <#Description#>
        public let interactionControl: InteractionControl?
        public let service: [String: AnyHashable]?
    }
    
    /// An Item received through the 'SendMessage' directive in `MessageAgent`.
    public struct SendMessage {
        /// The unique identifier to specify play service.
        public let playServiceId: String
        /// <#Description#>
        public let recipient: MessageAgentContact
        public let service: [String: AnyHashable]?
    }
}

// MARK: - MessageAgentDirectivePayload.SendCandidates + Codable

extension MessageAgentDirectivePayload.SendCandidates: Codable {
    enum CodingKeys: String, CodingKey {
        case playServiceId
        case intent
        case recipientIntended
        case searchScene
        case candidates
        case messageToSend
        case interactionControl
        case service
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        playServiceId = try container.decode(String.self, forKey: .playServiceId)
        intent = try? container.decode(String.self, forKey: .intent)
        recipientIntended = try? container.decode(MessageRecipientIntended.self, forKey: .recipientIntended)
        searchScene = try? container.decode(String.self, forKey: .searchScene)
        candidates = try? container.decode([MessageAgentContact].self, forKey: .candidates)
        messageToSend = try? container.decode(MessageToSendItem.self, forKey: .messageToSend)
        interactionControl = try? container.decode(InteractionControl.self, forKey: .interactionControl)
        service = try container.decodeIfPresent([String: AnyHashable].self, forKey: .service)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(playServiceId, forKey: .playServiceId)
        try container.encodeIfPresent(intent, forKey: .intent)
        try container.encodeIfPresent(recipientIntended, forKey: .recipientIntended)
        try container.encodeIfPresent(searchScene, forKey: .searchScene)
        try container.encodeIfPresent(candidates, forKey: .candidates)
        try container.encodeIfPresent(messageToSend, forKey: .messageToSend)
        try container.encodeIfPresent(interactionControl, forKey: .interactionControl)
        try container.encodeIfPresent(service, forKey: .service)
    }
}

// MARK: - MessageAgentDirectivePayload.SendMessage + Codable

extension MessageAgentDirectivePayload.SendMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case playServiceId
        case recipient
        case service
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        playServiceId = try container.decode(String.self, forKey: .playServiceId)
        recipient = try container.decode(MessageAgentContact.self, forKey: .recipient)
        service = try container.decodeIfPresent([String: AnyHashable].self, forKey: .service)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(playServiceId, forKey: .playServiceId)
        try container.encode(recipient, forKey: .recipient)
        try container.encodeIfPresent(service, forKey: .service)
    }
}
