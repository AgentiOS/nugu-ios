//
//  DirectiveSequencer.swift
//  NuguAgentsTests
//
//  Created by 신정섭님/AI Assistant iOS팀 on 5/15/25.
//  Copyright © 2025 SK Telecom Co., Ltd. All rights reserved.
//

import Foundation

import NuguCore

enum DirectiveSequencer {
    final class Dummy: DirectiveSequenceable {
        func add(directiveHandleInfos: NuguCore.DirectiveHandleInfos) {
        }
        
        func remove(directiveHandleInfos: NuguCore.DirectiveHandleInfos) {
        }
        
        func processDirective(_ directive: NuguCore.Downstream.Directive) {
        }
        
        func processAttachment(_ attachment: NuguCore.Downstream.Attachment) {
        }
        
        func cancelDirective(dialogRequestId: String) {
        }
    }
}
