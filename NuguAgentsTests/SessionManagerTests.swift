//
//  SessionManagerTests.swift
//  NuguAgentsTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/20/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Testing

@testable import NuguAgents

struct SessionManagerTests {
    @Test("setup session")
    func test1() async throws {
        let sut = SessionManager()
        sut.updateTimeout(timeout: 0.001)
        let session = Session(sessionId: "1", dialogRequestId: "2", playServiceId: "3")
        
        sut.set(session: session)
        
        let result = await withCheckedContinuation { continuation in
            let _ = sut.observe(NuguAgentNotification.Session.Set.self, queue: nil) { notification in
                continuation.resume(returning: notification.session)
            }
        }
        
        #expect(session == result)
    }
    
    @Test("unset session if session timeout has expired")
    func test2() async throws {
        let sut = SessionManager()
        sut.updateTimeout(timeout: 0.001)
        let session = Session(sessionId: "1", dialogRequestId: "2", playServiceId: "3")
        
        sut.set(session: session)
        
        let result = await withCheckedContinuation { continuation in
            let _ = sut.observe(NuguAgentNotification.Session.UnSet.self, queue: nil) { notification in
                continuation.resume(returning: notification.session)
            }
        }
        
        #expect(session == result)
    }
    
    @Test("active Session if set up session and activate it using same dialogRequestId")
    func test3() async throws {
        let sut = SessionManager()
        let dialogRequestId = "dialogRequestId"
        let session = Session(sessionId: "", dialogRequestId: dialogRequestId, playServiceId: "")
        
        let _ = await withCheckedContinuation { continuation in
            sut.set(session: session)
            sut.activate(dialogRequestId: dialogRequestId, category: .plugin(name: "test")) {
                continuation.resume()
            }
        }
        
        #expect(sut.activeSessions == [session])
    }
    
    @Test("not active Session if set up session and activate it using different dialogRequestId")
    func test4() async throws {
        let sut = SessionManager()
        let dialogRequestId = "dialogRequestId"
        let session = Session(sessionId: "", dialogRequestId: dialogRequestId, playServiceId: "")
        
        let _ = await withCheckedContinuation { continuation in
            sut.set(session: session)
            sut.activate(dialogRequestId: "", category: .plugin(name: "test")) {
                continuation.resume()
            }
        }
        
        #expect(sut.activeSessions == [])
    }
    
    @Test("deactive Session if set up session and deactivate it using same dialogRequestId")
    func test5() async throws {
        let sut = SessionManager()
        let dialogRequestId = "dialogRequestId"
        let pluginName = "pluginName"
        let session = Session(sessionId: "", dialogRequestId: dialogRequestId, playServiceId: "")
        sut.set(session: session)
        sut.activate(dialogRequestId: "1", category: .plugin(name: pluginName))
        
        let _ = await withCheckedContinuation { continuation in
            sut.deactivate(dialogRequestId: dialogRequestId, category: .plugin(name: pluginName)) {
                continuation.resume()
            }
        }
        
        #expect(sut.activeSessions == [])
    }
}
