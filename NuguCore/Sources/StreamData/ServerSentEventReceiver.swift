//
//  ServerSentEventReceiver.swift
//  NuguCore
//
//  Created by childc on 2020/03/05.
//  Copyright (c) 2020 SK Telecom Co., Ltd. All rights reserved.
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

class ServerSentEventReceiver: ServerSentEventReceivable {
    private let apiProvider: NuguApiProvidable
    private var pingCancellable: AnyCancellable?
    private let stateSubject = PassthroughSubject<ServerSentEventReceiverState, Never>()
    private let sseStateQueue = DispatchQueue(label: "com.sktelecom.romaine.core.server_sent_event_state")
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var state: ServerSentEventReceiverState = .unconnected {
        didSet {
            if oldValue != state {
                log.debug("server side event receiver state changed from: \(oldValue) to: \(state)")
                stateSubject.send(state)
                state == .connected ? startPing() : stopPing()
            }
        }
    }
    
    init(apiProvider: NuguApiProvidable) {
        self.apiProvider = apiProvider
    }
    
    var directive: AnyPublisher<MultiPartParser.Part, Error> {
        return apiProvider.directive2
            .handleEvents(receiveSubscription: { [weak self] _ in
                self?.sseStateQueue.async { [weak self] in
                    self?.state = .connecting
                }
            }, receiveOutput: { [weak self] _ in
                self?.sseStateQueue.async { [weak self] in
                    guard self?.state != .connected else { return }
                    self?.state = .connected
                }
            }, receiveCompletion: { [weak self] completion in
                self?.sseStateQueue.async { [weak self] in
                    guard case let .failure(error) = completion else { return }
                    self?.state = .disconnected(error: error)
                }
            }, receiveCancel: { [weak self] in
                self?.sseStateQueue.async { [weak self] in
                    self?.state = .unconnected
                }
            })
            .eraseToAnyPublisher()
    }
    
    var stateObserver: AnyPublisher<ServerSentEventReceiverState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
}

// MARK: - ping

private extension ServerSentEventReceiver {
    private enum Const {
        static let minPingInterval = 180
        static let maxPingInterval = 300
        static let maxRetryCount = 3
    }
    
    func startPing() {
        log.debug("Try to start ping schedule")
        
        let randomPingTime = Int.random(in: Const.minPingInterval..<Const.maxPingInterval)
        let pingCancellable = Timer
            .publish(every: Double(randomPingTime), on: .main, in: .common)
            .setFailureType(to: Error.self)
            .flatMap { [weak self] _ -> AnyPublisher<Void, Error> in
                guard let apiProvider = self?.apiProvider else {
                    return Fail(error: NetworkError.badRequest).eraseToAnyPublisher()
                }
                
                return apiProvider.ping2.eraseToAnyPublisher()
            }
            .retry(3)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        
        sseStateQueue.async { [weak self] in
            guard let self else { return }
            self.pingCancellable?.cancel()
            self.pingCancellable = pingCancellable
            pingCancellable.store(in: &cancellables)
            log.debug("Ping schedule for server initiated directive is set. It will be triggered \(randomPingTime) seconds later.")
        }
    }
    
    // TODO: StreamDataRouter에서 Combine 변환 작업 완료 시, 삭제
    func stopPing() {
        log.debug("Try to stop ping schedule")
        
        sseStateQueue.async { [weak self] in
            guard let self else { return }
            pingCancellable?.cancel()
            pingCancellable = nil
        }
    }
}
