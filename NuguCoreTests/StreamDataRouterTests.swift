//
//  StreamDataRouterTests.swift
//  NuguCoreTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/16/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Testing
import Combine

@testable import NuguCore

struct StreamDataRouterTests {
    @Test("Receiver state changes to Connecting if startReceiveServerInitiatedDirective called")
    func test1() async throws {
        var cancellables = Set<AnyCancellable>()
        let nuguApiProvider = NuguApiProvider.Mock()
        let sut = StreamDataRouter(directiveSequencer: DirectiveSequencer.Dummy(), nuguApiProvider: nuguApiProvider)
        
        let result = await withCheckedContinuation { continuation in
            NotificationCenter.default.publisher(for: .serverSentEventReceiverStateDidChange)
                .sink { state in
                    guard let state = state.userInfo?["value"] as? ServerSentEventReceiverState else { return }
                    continuation.resume(returning: state)
                }
                .store(in: &cancellables)
            
            sut.startReceiveServerInitiatedDirective()
        }
        
        #expect(result == .connecting)
    }
    
    @Test("Receiver state changes to connected if startReceiveServerInitiatedDirective called And any directive received")
    func test2() async throws {
        var cancellables = Set<AnyCancellable>()
        let nuguApiProvider = NuguApiProvider.Mock()
        let sut = StreamDataRouter(directiveSequencer: DirectiveSequencer.Dummy(), nuguApiProvider: nuguApiProvider)
        
        var result = await withCheckedContinuation { continuation in
            NotificationCenter.default.publisher(for: .serverSentEventReceiverStateDidChange)
                .sink { state in
                    guard let state = state.userInfo?["value"] as? ServerSentEventReceiverState else { return }
                    continuation.resume(returning: state)
                }
                .store(in: &cancellables)
            
            sut.startReceiveServerInitiatedDirective()
        }
        
        #expect(result == .connecting)
        cancellables.removeAll()
        
        result = await withCheckedContinuation { continuation in
            NotificationCenter.default.publisher(for: .serverSentEventReceiverStateDidChange)
                .sink { state in
                    guard let state = state.userInfo?["value"] as? ServerSentEventReceiverState else { return }
                    continuation.resume(returning: state)
                }
                .store(in: &cancellables)
            
            nuguApiProvider.directiveSubject.send(.init(header: [:], body: Data()))
        }
        
        #expect(result == .connected)
    }
    
    @Test("startReceiveServerInitiatedDirective completion returns prepared when connected Server and received any directive")
    func test3() async throws {
        let nuguApiProvider = NuguApiProvider.Mock()
        let sut = StreamDataRouter(directiveSequencer: DirectiveSequencer.Dummy(), nuguApiProvider: nuguApiProvider)
        
        let result = await withCheckedContinuation { continuation in
            sut.startReceiveServerInitiatedDirective { state in
                continuation.resume(returning: state)
            }
            
            nuguApiProvider.directiveSubject.send(.init(header: [:], body: Data()))
        }
        
        #expect(result == .prepared)
    }
}

// MARK: - Equatable for testing

extension StreamDataState: @retroactive Equatable {
    public static func == (lhs: StreamDataState, rhs: StreamDataState) -> Bool {
        switch (lhs, rhs) {
        case (.prepared, .prepared): true
        case (.sent, .sent): true
        case (let .received(lhsPart), let .received(rhsPart)): lhsPart.header.type == rhsPart.header.type
        case (.finished, .finished): true
        case (let .error(lhsError), let .error(rhsError)): lhsError.localizedDescription == rhsError.localizedDescription
        default: false
        }
    }
}
