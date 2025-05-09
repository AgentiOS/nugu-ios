//
//  Downstream.swift
//  NuguCore
//
//  Created by MinChul Lee on 11/22/2019.
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

/// An enum that contains the data structures to be received from the server.
public enum Downstream {
    /// A structure that contains payload and headers for the directive.
    public struct Directive: Codable {
        /// A structure that contains header fields for the directive.
        public let header: Header
        /// A JSON object that contains payload for the directive.
        public let payload: Data
        
        /// Creates an instance of an `Directive`.
        /// - Parameters:
        ///   - header: A structure that contains header fields for the directive.
        ///   - payload: A JSON object that contains payload for the directive.
        public init(header: Header, payload: Data) {
            self.header = header
            self.payload = payload
        }
    }
    
    /// A structure that contains data and headers for the attachment.
    ///
    /// This is sub-data of `Directive`
    public struct Attachment: Codable {
        /// A structure that contains header fields for the attachment.
        public let header: Header
        /// The sequence number of attachment.
        public let seq: Int
        /// The binary data.
        public let content: Data
        /// Indicates whether this attachment is the last one.
        public let isEnd: Bool
        /// The message identifier of the directive.
        public let parentMessageId: String
        /// The mime type of attachment.
        public let mediaType: String
        
        /// Creates an instance of an `Attachment`.
        /// - Parameters:
        ///   - header: A structure that contains header fields for the attachment.
        ///   - seq: The sequence number of attachment.
        ///   - content: The binary data.
        ///   - isEnd: Indicates whether this attachment is the last one.
        ///   - parentMessageId: The message identifier of the directive.
        ///   - mediaType: The mime type of attachment.
        public init(header: Header, seq: Int, content: Data, isEnd: Bool, parentMessageId: String, mediaType: String) {
            self.header = header
            self.seq = seq
            self.content = content
            self.isEnd = isEnd
            self.parentMessageId = parentMessageId
            self.mediaType = mediaType
        }
    }
    
    /// A structure that contains header fields for the directive.
    public struct Header: Codable {
        /// The namespace of directive.
        public let namespace: String
        /// The name of directive.
        public let name: String
        /// The identifier for the response that generated by server.
        public let dialogRequestId: String
        /// The unique identifier for the directive.
        public let messageId: String
        /// The version of capability interface.
        public let version: String
        /// The timestamp of directive.
        public let messageTimestamp: Int?
        
        /// Creates an instance of an `Header`.
        /// - Parameters:
        ///   - namespace: The namespace of directive.
        ///   - name: The name of directive.
        ///   - dialogRequestId: The identifier for the response that generated by server.
        ///   - messageId: The unique identifier for the directive.
        ///   - version: The version of capability interface.
        ///   - messageTimestamp: The timestamp of directive
        public init(
            namespace: String,
            name: String,
            dialogRequestId: String,
            messageId: String,
            version: String,
            messageTimestamp: Int? = nil
        ) {
            self.namespace = namespace
            self.name = name
            self.dialogRequestId = dialogRequestId
            self.messageId = messageId
            self.version = version
            self.messageTimestamp = messageTimestamp
        }
    }
}

// MARK: - Downstream.Header

extension Downstream.Header {
    /// The type of directive.
    public var type: String { "\(namespace).\(name)" }
    
}

// MARK: - Downstream.Header + CustomStringConvertible

/// :nodoc:
extension Downstream.Header: CustomStringConvertible {
    public var description: String {
        return "\(type)(\(messageId))"
    }
}

// MARK: - Downstream.Attachment + CustomStringConvertible

/// :nodoc:
extension Downstream.Attachment: CustomStringConvertible {
    public var description: String {
        return "\(header)), \(seq), \(isEnd)"
    }
}

// MARK: - Downstream.Directive

extension Downstream.Directive {
    /// A dictionary that contains payload for the directive.
    public var payloadDictionary: [String: AnyHashable]? {
        try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: AnyHashable]
    }
    
    public var asyncKey: AsyncKey? {
        guard let asyncKeyDictionary = payloadDictionary?["asyncKey"] as? [String: AnyHashable],
              let eventDialogRequestId = asyncKeyDictionary["eventDialogRequestId"] as? String,
              let stateRawValue = asyncKeyDictionary["state"] as? String,
              let state = AsyncKey.State(rawValue: stateRawValue),
              let routing = asyncKeyDictionary["routing"] as? String else {
            return nil
        }
        return .init(eventDialogRequestId: eventDialogRequestId, state: state, routing: routing)
    }
}
