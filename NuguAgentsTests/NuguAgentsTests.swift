//
//  NuguAgentsTests.swift
//  NuguAgentsTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/13/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Testing

@testable import NuguAgents

struct NuguAgentsTests {
    @Test("interactionControlManager start")
    func interactionControlManagerTest1() async throws {
        let sut = InteractionControlManager()
        sut.start(mode: .multiTurn, category: .audioPlayer)
        
        let result = await withCheckedContinuation { continuation in
            NotificationCenter.default.addObserver(
                forName: Notification.Name.interactionControlDidChange,
                object: nil,
                queue: nil
            ) { notification in
                let multiTurn = notification.userInfo?["multiTurn"] as? Bool
                
                if multiTurn == true {
                    continuation.resume(returning: multiTurn)
                }
            }
        }
        
        #expect(result == true)
    }
    
    @Test("interactionControlManager start-finish")
    func interactionControlManagerTest2() async throws {
        let sut = InteractionControlManager()
        sut.start(mode: .multiTurn, category: .audioPlayer)
        sut.finish(mode: .multiTurn, category: .audioPlayer)
        
        let result = await withCheckedContinuation { continuation in
            NotificationCenter.default.addObserver(
                forName: Notification.Name.interactionControlDidChange,
                object: nil,
                queue: nil
            ) { notification in
                let multiTurn = notification.userInfo?["multiTurn"] as? Bool
                
                if multiTurn == false {
                    continuation.resume(returning: multiTurn)
                }
            }
        }
        
        #expect(result == false)
    }
}
