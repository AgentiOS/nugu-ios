//
//  DirectiveHandleResult.swift
//  NuguCore
//
//  Created by MinChul Lee on 2020/07/08.
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
public enum DirectiveHandleResult: Equatable {
    case failed(_ description: String)
    case canceled
    case stopped(directiveCancelPolicy: DirectiveCancelPolicy)
    case finished
    
    public static func == (lhs: DirectiveHandleResult, rhs: DirectiveHandleResult) -> Bool {
        switch (lhs, rhs) {
        case (.failed(let lhsMessage), .failed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.canceled, .canceled):
            return true
        case (.stopped(let lhsPolicy), .stopped(let rhsPolicy)):
            return lhsPolicy == rhsPolicy
        case (.finished, .finished):
            return true
        default:
            return false
        }
    }
}
