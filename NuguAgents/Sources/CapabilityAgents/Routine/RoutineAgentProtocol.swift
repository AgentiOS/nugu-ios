//
//  RoutineAgentProtocol.swift
//  NuguAgents
//
//  Created by MinChul Lee on 2020/07/07.
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

public protocol RoutineAgentProtocol: CapabilityAgentable {
    var state: RoutineState { get }
    var routineItem: RoutineItem? { get }
    var interruptTimeoutInSeconds: Int? { get set }
    
    /**
     Move to previous action
     */
    func previous(completion: @escaping (Bool) -> Void)
    
    /**
     Move to next action
     */
    func next(completion: @escaping (Bool) -> Void)
    
    /**
     Pause routine. The routine state changes to Interrupt.
     */
    func pause()
        
    /**
     Stop routine
     */
    func stop()
    
    var delegate: RoutineAgentDelegate? { get set }
}
