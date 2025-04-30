//
//  DisplayAgent+Event.swift
//  NuguAgents
//
//  Created by yonghoonKwon on 10/06/2019.
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

// MARK: - Event

extension DisplayAgent {
    struct Event {
        let typeInfo: TypeInfo
        let playServiceId: String
        let referrerDialogRequestId: String?
        
        enum TypeInfo {
            case elementSelected(token: String, postback: [String: AnyHashable]?, service: [String: AnyHashable]?)
            case closeSucceeded(service: [String: AnyHashable]?)
            case closeFailed(service: [String: AnyHashable]?)
            case controlFocusSucceeded(direction: DisplayControlPayload.Direction, service: [String: AnyHashable]?)
            case controlFocusFailed(direction: DisplayControlPayload.Direction, service: [String: AnyHashable]?)
            case controlScrollSucceeded(direction: DisplayControlPayload.Direction, interactionControl: InteractionControl?, service: [String: AnyHashable]?)
            case controlScrollFailed(direction: DisplayControlPayload.Direction, interactionControl: InteractionControl?, service: [String: AnyHashable]?)
            case triggerChild(parentToken: String, data: [String: AnyHashable])
        }
    }
}

// MARK: - Eventable

extension DisplayAgent.Event: Eventable {
    var payload: [String: AnyHashable] {
        var payload: [String: AnyHashable] = [
            "playServiceId": playServiceId
        ]
        switch typeInfo {
        case .elementSelected(let token, let postback, let service):
            payload["token"] = token
            if let postback = postback {
                payload["postback"] = postback
            }
            
            if let service {
                payload["service"] = service
            }
        case let .closeSucceeded(service),
            let .closeFailed(service):
            if let service {
                payload["service"] = service
            }
        case .controlFocusSucceeded(let direction, let service),
                .controlFocusFailed(let direction, let service):
            payload["direction"] = direction
            
            if let service {
                payload["service"] = service
            }
        case .controlScrollSucceeded(let direction, let interactionControl, let service),
             .controlScrollFailed(let direction, let interactionControl, let service):
            payload["direction"] = direction
            
            if let interactionControl = interactionControl,
               let interactionControlData = try? JSONEncoder().encode(interactionControl),
               let interactionControlDictionary = try? JSONSerialization.jsonObject(with: interactionControlData, options: []) as? [String: AnyHashable] {
                payload["interactionControl"] = interactionControlDictionary
            }
            
            if let service {
                payload["service"] = service
            }
        case .triggerChild(let parentToken, let data):
            payload["parentToken"] = parentToken
            payload["data"] = data
        default:
            break
        }
        return payload
    }
    
    var name: String {
        switch typeInfo {
        case .elementSelected:
            return "ElementSelected"
        case .closeSucceeded:
            return "CloseSucceeded"
        case .closeFailed:
            return "CloseFailed"
        case .controlFocusSucceeded:
            return "ControlFocusSucceeded"
        case .controlFocusFailed:
            return "ControlFocusFailed"
        case .controlScrollSucceeded:
            return "ControlScrollSucceeded"
        case .controlScrollFailed:
            return "ControlScrollFailed"
        case .triggerChild:
            return "TriggerChild"
        }
    }
}
