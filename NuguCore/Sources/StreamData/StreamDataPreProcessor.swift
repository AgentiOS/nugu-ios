//
//  StreamDataPreProcessor.swift
//  NuguCore
//
//  Created by jaycesub on 2025/06/26.
//  Copyright (c) 2025 SK Telecom Co., Ltd. All rights reserved.
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

import NuguUtils

public protocol StreamDataPreProcessable {
    func add(_ processor: DirectivePreProcessable)
    func preProcess(directives: [Downstream.Directive]) -> [Downstream.Directive]
}

public final class StreamDataPreProcessor: StreamDataPreProcessable {
    @Atomic private var processors: [DirectivePreProcessable] = []
    public init() {}
    
    public func add(_ processor: DirectivePreProcessable) {
        _processors.mutate { $0.append(processor) }
    }
    
    public func preProcess(directives: [Downstream.Directive]) -> [Downstream.Directive] {
        var directives = directives
        for processor in processors {
            directives = processor.preProcess(directives: directives)
        }
        return directives
    }
}
