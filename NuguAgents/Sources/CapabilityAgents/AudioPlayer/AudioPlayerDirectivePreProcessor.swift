//
//  AudioPlayerDirectivePreProcessor.swift
//  NuguAgents
//
//  Created by jaycesub on 2025/06/27.
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

public final class AudioPlayerDirectivePreProcessor: DirectivePreProcessable {
    public init() {}
    
    public func preProcess(directives: [Downstream.Directive]) -> [Downstream.Directive] {
        guard (directives.contains { $0.header.namespace == CapabilityAgentCategory.display.name }) == false else { return directives }
        
        guard let playDirective = (directives.first { $0.header.type == "AudioPlayer.Play" }) else { return directives }
        let templateHeaer: Downstream.Header = .init(
            namespace: playDirective.header.namespace,
            name: "Template",
            dialogRequestId: playDirective.header.dialogRequestId,
            messageId: playDirective.header.messageId,
            version: playDirective.header.version
        )
        let templateDirective = Downstream.Directive.init(header: templateHeaer, payload: playDirective.payload, asyncKey: playDirective.asyncKey)
        
        return [templateDirective] + directives
    }
}
