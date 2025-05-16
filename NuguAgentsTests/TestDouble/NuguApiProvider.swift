//
//  NuguApiProvider.swift
//  NuguAgentsTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/15/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Foundation
import Combine

import NuguCore

import RxSwift

enum NuguApiProvider {
    final class Dummy: NuguApiProvidable {
        var policies2: AnyPublisher<NuguCore.Policy, Error> { Empty().eraseToAnyPublisher() }
        
        var directive2: AnyPublisher<NuguCore.MultiPartParser.Part, Error> { Empty().eraseToAnyPublisher() }
        
        var ping2: AnyPublisher<Void, Error> { Empty().eraseToAnyPublisher() }
        
        func events(boundary: String, httpHeaderFields: [String : String]?, inputStream: InputStream) -> AnyPublisher<NuguCore.MultiPartParser.Part, Error> {
            Empty().eraseToAnyPublisher()
        }
        
        var policies: Single<NuguCore.Policy> { .never() }
        
        var directive: Observable<NuguCore.MultiPartParser.Part> { .empty() }
        
        var ping: Completable { .empty() }
        
        func setRequestTimeout(_ timeInterval: TimeInterval) {
        }
        
        func events(boundary: String, httpHeaderFields: [String : String]?, inputStream: InputStream) -> Observable<NuguCore.MultiPartParser.Part> {
            .never()
        }
    }
}
