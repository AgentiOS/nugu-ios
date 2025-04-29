//
//  PhoneCallAgent+Event.swift
//  NuguAgents
//
//  Created by yonghoonKwon on 2020/04/29.
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

import NuguCore

extension PhoneCallAgent {
    struct Event {
        let typeInfo: TypeInfo
        let playServiceId: String
        let referrerDialogRequestId: String?
        
        enum TypeInfo {
            case candidatesListed(interactionControl: InteractionControl?, service: [String: AnyHashable]?)
            case makeCallFailed(errorCode: PhoneCallErrorCode, callType: PhoneCallType, service: [String: AnyHashable]?)
            case makeCallSucceeded(recipient: PhoneCallPerson, service: [String: AnyHashable]?)
        }
    }
}

// MARK: - Eventable

extension PhoneCallAgent.Event: Eventable {
    var payload: [String: AnyHashable] {
        var payload: [String: AnyHashable] = [
            "playServiceId": playServiceId
        ]
        
        switch typeInfo {
        case .candidatesListed(let interactionControl, let service):
            if let interactionControl = interactionControl,
               let interactionControlData = try? JSONEncoder().encode(interactionControl),
               let interactionControlDictionary = try? JSONSerialization.jsonObject(with: interactionControlData, options: []) as? [String: AnyHashable] {
                payload["interactionControl"] = interactionControlDictionary
            }
            
            if let service {
                payload["service"] = service
            }
        case .makeCallFailed(let errorCode, let callType, let service):
            payload["errorCode"] = errorCode.rawValue
            payload["callType"] = callType.rawValue
            if let service {
                payload["service"] = service
            }
        case .makeCallSucceeded(let recipient, let service):
            if let recipientData = try? JSONEncoder().encode(recipient),
                let recipientDictionary = try? JSONSerialization.jsonObject(with: recipientData, options: []) as? [String: AnyHashable] {
                payload["recipient"] = recipientDictionary
            }
            if let service {
                payload["service"] = service
            }
        }
        
        return payload
    }
    
    var name: String {
        switch typeInfo {
        case .candidatesListed:
            return "CandidatesListed"
        case .makeCallFailed:
            return "MakeCallFailed"
        case .makeCallSucceeded:
            return "MakeCallSucceeded"
        }
    }
}
