//
//  NuguCoreTests.swift
//  NuguCoreTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/13/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Testing

@testable import NuguCore
@testable import NuguUtils

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
    
    @Test("playSyncManager startPlay")
    func playSyncManagerTest1() async throws {
        let contextManager = ContextManager()
        let sut = PlaySyncManager(contextManager: contextManager)
        
        let playStackServiceId = "playStackServiceId"
        let dialogRequestId = "dialogRequestId"
        let messageId = "messageId"
        sut.startPlay(
            property: PlaySyncProperty(
                layerType: .media,
                contextType: .display
            ),
            info: PlaySyncInfo(
                playStackServiceId: playStackServiceId,
                dialogRequestId: dialogRequestId,
                messageId: messageId,
                duration: NuguTimeInterval(seconds: 3)
            )
        )
        
        let result = await withCheckedContinuation { continuation in
            NotificationCenter.default.addObserver(
                forName: Notification.Name.playSyncPropertiesDidChange,
                object: nil,
                queue: nil
            ) { notification in
                let result = (notification.userInfo?["properties"] as? [(property: PlaySyncProperty, info: PlaySyncInfo)])?.first
                if let property = result?.property,
                   property.layerType == .media,
                   property.contextType == .display,
                    let info = result?.info,
                   info.playStackServiceId == playStackServiceId,
                   info.dialogRequestId == dialogRequestId,
                   info.messageId == messageId {
                    continuation.resume(returning: true)
                }
            }
        }
        
        #expect(result == true)
    }
    
    @Test("playSyncManager startPlay")
    func playSyncManagerTest2() async throws {
        let contextManager = ContextManager()
        let sut = PlaySyncManager(contextManager: contextManager)
        
        let property = PlaySyncProperty(
            layerType: .media,
            contextType: .display
        )
        let playStackServiceId = "playStackServiceId"
        let dialogRequestId = "dialogRequestId"
        let messageId = "messageId"
        sut.startPlay(
            property: property,
            info: PlaySyncInfo(
                playStackServiceId: playStackServiceId,
                dialogRequestId: dialogRequestId,
                messageId: messageId,
                duration: NuguTimeInterval(seconds: 3)
            )
        )
        
        sut.endPlay(property: property)
        
        let result = await withCheckedContinuation { continuation in
            NotificationCenter.default.addObserver(
                forName: Notification.Name.playSyncPropertyDidRelease,
                object: nil,
                queue: nil
            ) { notification in
                if let property = notification.userInfo?["property"] as? PlaySyncProperty,
                   property.layerType == .media,
                   property.contextType == .display,
                   (notification.userInfo?["messageId"] as? String) == messageId {
                    continuation.resume(returning: true)
                }
            }
        }
        
        #expect(result == true)
    }
}
