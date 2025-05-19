//
//  DirectiveSequencer.swift
//  NuguCoreTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/16/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Foundation

import NuguCore

enum DirectiveSequencer {
    final class Dummy: DirectiveSequenceable {
        func add(directiveHandleInfos: DirectiveHandleInfos) {
        }
        
        func remove(directiveHandleInfos: DirectiveHandleInfos) {
        }
        
        func processDirective(_ directive: Downstream.Directive) {
        }
        
        func processAttachment(_ attachment: Downstream.Attachment) {
        }
        
        func cancelDirective(dialogRequestId: String) {
        }
    }
}
