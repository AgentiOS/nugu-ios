//
//  Attachable+makeAttachmentMessage.swift
//  NuguAgents
//
//  Created by 이민철님/AI Assistant개발Cell on 2020/11/16.
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

extension Attachable {
    // swiftlint:disable function_parameter_count
    func makeAttachmentMessage(
        property: CapabilityAgentProperty,
        dialogRequestId: String,
        referrerDialogRequestId: String?,
        attachmentSeq: Int32,
        isEnd: Bool,
        speechData: Data? = nil
    ) -> Upstream.Attachment {
        let header = Upstream.Header(
            namespace: property.name,
            name: name,
            version: property.version,
            dialogRequestId: dialogRequestId,
            messageId: TimeUUID().hexString,
            referrerDialogRequestId: referrerDialogRequestId
        )
        
        return Upstream.Attachment(
            header: header,
            seq: attachmentSeq,
            isEnd: isEnd,
            type: type,
            content: speechData
        )
    }
    
    func makeAttachmentImage(
        property: CapabilityAgentProperty,
        eventIdentifier: EventIdentifier,
        attachmentSeq: Int32,
        isEnd: Bool,
        imageData: Data
    ) -> Upstream.Attachment {
        let header = Upstream.Header(
            namespace: property.name,
            name: name,
            version: property.version,
            dialogRequestId: eventIdentifier.dialogRequestId,
            messageId: eventIdentifier.messageId,
            referrerDialogRequestId: eventIdentifier.dialogRequestId
        )
        
        return Upstream.Attachment(
            header: header,
            seq: attachmentSeq,
            isEnd: isEnd,
            type: type,
            content: imageData
        )
    }
}
