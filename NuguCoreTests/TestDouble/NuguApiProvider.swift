//
//  NuguApiProvider.swift
//  NuguCoreTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/16/25.
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
    
    final class Mock: NuguApiProvidable {
        let policiesSubject = PassthroughSubject<Policy, Error>()
        var policies2: AnyPublisher<Policy, Error> { policiesSubject.eraseToAnyPublisher() }
        
        let directiveSubject = PassthroughSubject<MultiPartParser.Part, Error>()
        var directive2: AnyPublisher<MultiPartParser.Part, Error> { directiveSubject.eraseToAnyPublisher() }
        
        let pingSubject = PassthroughSubject<Void, Error>()
        var ping2: AnyPublisher<Void, Error> { pingSubject.eraseToAnyPublisher() }
        
        let eventsSubject = PassthroughSubject<MultiPartParser.Part, Error>()
        func events(boundary: String, httpHeaderFields: [String : String]?, inputStream: InputStream) -> AnyPublisher<MultiPartParser.Part, Error> {
            eventsSubject.eraseToAnyPublisher()
        }
        
        func setRequestTimeout(_ timeInterval: TimeInterval) {
        }

        // legacy
        var policies: Single<NuguCore.Policy> { .never() }
        var directive: Observable<NuguCore.MultiPartParser.Part> { .empty() }
        var ping: Completable { .empty() }
        func events(boundary: String, httpHeaderFields: [String : String]?, inputStream: InputStream) -> Observable<NuguCore.MultiPartParser.Part> {
            .never()
        }
    }
}
