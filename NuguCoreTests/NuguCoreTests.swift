//
//  NuguCoreTests.swift
//  NuguCoreTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/13/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Testing

@testable import NuguCore

struct NuguCoreTests {
    @Test("get contexts using combine")
    func contextManagerTest1() async throws {
        let sut = ContextManager()
        
        let expectNamespaces: Set<String> = ["test1", "test2", "test3"]
        
        expectNamespaces.forEach {
            sut.addProvider(makeContextProvider(namespace: $0))
        }
        
        let result = await withCheckedContinuation { continuation in
            let _ = sut.contexts()
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { contextInfo in
                        continuation.resume(returning: Set(contextInfo.map(\.name)))
                    }
                )
        }
        
        #expect(result == expectNamespaces)
        
        func makeContextProvider(namespace: String) -> ContextInfoProviderType {
            { completion in
                completion(.init(contextType: .client, name: namespace, payload: [:] as [String: AnyHashable]))
            }
        }
    }
}
