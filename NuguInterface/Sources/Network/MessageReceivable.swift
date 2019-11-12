//
//  MessageReceivable.swift
//  NuguInterface
//
//  Created by MinChul Lee on 19/04/2019.
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

/// <#Description#>
public protocol MessageReceivable {
    /// <#Description#>
    /// - Parameter directive: <#directive description#>
    func receive(directive: DirectiveProtocol)
    /// <#Description#>
    /// - Parameter attachment: <#attachment description#>
    func receive(attachment: AttachmentProtocol)
    /// <#Description#>
    /// - Parameter receiveMessageDelegate: <#receiveMessageDelegate description#>
    func add(receiveMessageDelegate: ReceiveMessageDelegate)
    /// <#Description#>
    /// - Parameter receiveMessageDelegate: <#receiveMessageDelegate description#>
    func remove(receiveMessageDelegate: ReceiveMessageDelegate)
}