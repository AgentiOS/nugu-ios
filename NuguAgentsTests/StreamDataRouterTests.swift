//
//  StreamDataRouterTests.swift
//  NuguAgentsTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/15/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Testing
import Combine

@testable import NuguCore
@testable import NuguAgents

struct StreamDataRouterTests {
    @Test("sent event using event publisher, context publisher")
    func streamDataRouterTest1() async throws {
        let sut = StreamDataRouter(directiveSequencer: DirectiveSequencer.Dummy(), nuguApiProvider: NuguApiProvider.Dummy())
        
        await withCheckedContinuation { continuation in
            _ = sut.sendEvent(
                makeEventPublisher(name: ""),
                eventIdentifier: .init(),
                context: makeContextPublisher(context: []),
                property: .init(category: .plugin(name: ""), version: "")
            ) { state in
                guard case .sent = state else { return }
                continuation.resume()
            }
        }
        
        #expect(true)
    }
    
    @Test("sent event using event struct, context publisher")
    func streamDataRouterTest2() async throws {
        let sut = StreamDataRouter(directiveSequencer: DirectiveSequencer.Dummy(), nuguApiProvider: NuguApiProvider.Dummy())
        
        await withCheckedContinuation { continuation in
            _ = sut.sendEvent(
                TestEvent(name: "", payload: [:]),
                eventIdentifier: .init(),
                context: makeContextPublisher(context: []),
                property: .init(category: .plugin(name: ""), version: "")
            ) { state in
                guard case .sent = state else { return }
                continuation.resume()
            }
        }
        
        #expect(true)
    }
}

private extension StreamDataRouterTests {
    func makeEventPublisher(name: String) -> AnyPublisher<Eventable, Error> {
        Just(TestEvent(name: "", payload: [:]))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func makeContextPublisher(context: [ContextInfo]) -> AnyPublisher<[ContextInfo], Error> {
        Just(context)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

struct TestEvent: Eventable {
    let name: String
    let payload: [String: AnyHashable]
}
