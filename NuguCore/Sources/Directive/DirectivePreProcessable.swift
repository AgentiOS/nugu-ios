//
//  DirectivePreProcessable.swift
//  NuguCore
//
//  Created by 신정섭님/AI Assistant iOS팀 on 6/26/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Foundation

public protocol DirectivePreProcessable {
    func process(directives: [Downstream.Directive]) -> [Downstream.Directive]
}
