//
//  NuguApiProvider.swift
//  NuguAgentsTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/15/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Foundation

import NuguCore

import RxSwift

enum NuguApiProvider {
    final class Dummy: NuguApiProvidable {
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
