//
//  ServerSentEventReceiverTests.swift
//  NuguCoreTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/16/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Testing
import Combine

@testable import NuguCore

struct ServerSentEventReceiverTests {
    @Test("Connection state changes to connecting if subscribe to directive publisher")
    func test1() async throws {
        var cancellables = Set<AnyCancellable>()
        let apiProvider = NuguApiProvider.Mock()
        let sut = ServerSentEventReceiver(apiProvider: apiProvider)
        
        let result = await withCheckedContinuation { continuation in
            sut.stateObserver2
                .sink { state in
                    continuation.resume(returning: state)
                }
                .store(in: &cancellables)
            
            sut.directive2
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                .store(in: &cancellables)
        }
        
        #expect(result == .connecting)
    }
    
    @Test("Connection state changes to connected if directive received")
    func test2() async throws {
        var cancellables = Set<AnyCancellable>()
        let apiProvider = NuguApiProvider.Mock()
        let sut = ServerSentEventReceiver(apiProvider: apiProvider)
        
        sut.directive2
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
        
        let result = await withCheckedContinuation { continuation in
            sut.stateObserver2
                .sink { state in
                    guard state != .connecting else { return }
                    continuation.resume(returning: state)
                }
                .store(in: &cancellables)
            
            apiProvider.directiveSubject.send(.init(header: [:], body: Data()))
        }
        
        #expect(result == .connected)
    }
    
    @Test("Connection state changes to unconnected if unsubscribe to directive publisher")
    func test3() async throws {
        var cancellables = Set<AnyCancellable>()
        var directiveCancellables: AnyCancellable?
        let apiProvider = NuguApiProvider.Mock()
        let sut = ServerSentEventReceiver(apiProvider: apiProvider)
        
        directiveCancellables = sut.directive2
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        
        let result = await withCheckedContinuation { continuation in
            sut.stateObserver2
                .sink { state in
                    guard state != .connecting else { return }
                    continuation.resume(returning: state)
                }
                .store(in: &cancellables)
            
            directiveCancellables?.cancel()
        }
        
        #expect(result == .unconnected)
    }
    
    @Test("Connection state changes to disconnected if receive directive error")
    func test4() async throws {
        var cancellables = Set<AnyCancellable>()
        let apiProvider = NuguApiProvider.Mock()
        let sut = ServerSentEventReceiver(apiProvider: apiProvider)
        
        sut.directive2
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
        
        let result = await withCheckedContinuation { continuation in
            sut.stateObserver2
                .sink { state in
                    guard state != .connecting else { return }
                    continuation.resume(returning: state)
                }
                .store(in: &cancellables)
            
            apiProvider.directiveSubject.send(completion: .failure(NetworkError.serverError))
        }
        
        #expect(result == .disconnected(error: NetworkError.serverError))
    }
}
