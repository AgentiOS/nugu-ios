//
//  InteractionControlManager.swift
//  NuguAgents
//
//  Created by MinChul Lee on 2020/08/07.
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
import Combine

import NuguUtils
import NuguCore

public class InteractionControlManager: InteractionControlManageable {
    private let interactionDispatchQueue = DispatchQueue(label: "com.sktelecom.romaine.interaction_control", qos: .userInitiated)
    private var interactionControls = Set<CapabilityAgentCategory>()
    private var timeoutTimers = [String: AnyCancellable]()
    
    public init() {}
}

// MARK: - InteractionControlManageable

public extension InteractionControlManager {
    func start(mode: InteractionControl.Mode, category: CapabilityAgentCategory) {
        log.debug(category)
        interactionDispatchQueue.async { [weak self] in
            guard let self, mode == .multiTurn else { return }
            
            addTimer(category: category)
            interactionControls.insert(category)
            if interactionControls.count == 1 {
                post(NuguAgentNotification.InteractionControl.MultiTurn(multiTurn: true))
            }
        }
    }
    
    func finish(mode: InteractionControl.Mode, category: CapabilityAgentCategory) {
        log.debug(category)
        interactionDispatchQueue.async { [weak self] in
            guard let self, mode == .multiTurn else { return }
            
            removeTimer(category: category)
            clearInterfaction(category)
        }
    }
}

private extension InteractionControlManager {
    func addTimer(category: CapabilityAgentCategory) {
        log.debug(category)
        
        timeoutTimers[category.name] = Just(())
            .delay(
                for: .seconds(InteractionControlConst.timeout),
                scheduler: interactionDispatchQueue
            )
            .sink { [weak self] _ in
                guard let self else { return }
                
                log.debug("Timer fired. \(category)")
                clearInterfaction(category)
            }
    }
    
    func removeTimer(category: CapabilityAgentCategory) {
        log.debug(category)
        timeoutTimers[category.name]?.cancel()
        timeoutTimers[category.name] = nil
    }
    
    func clearInterfaction(_ category: CapabilityAgentCategory) {
        interactionControls.remove(category)
        
        if interactionControls.isEmpty {
            post(NuguAgentNotification.InteractionControl.MultiTurn(multiTurn: false))
        }
    }
}

// MARK: - Observer

extension Notification.Name {
    static let interactionControlDidChange = Notification.Name("com.sktelecom.romain.notification.name.interaction_control_did_change")
}

public extension NuguAgentNotification {
    enum InteractionControl {
        public struct MultiTurn: TypedNotification {
            public static let name: Notification.Name = .interactionControlDidChange
            public let multiTurn: Bool
            
            public static func make(from: [String: Any]) -> MultiTurn? {
                guard let multiTurn = from["multiTurn"] as? Bool else { return nil }
                
                return MultiTurn(multiTurn: multiTurn)
            }
        }
    }
}
