//
//  NoteKindLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import Foundation

extension Note.Kind {
    var label: String {
        switch self {
        case .report: String(localized: .noteKindReport)
        case .reminder: String(localized: .noteKindReminder)
        case .feedback: String(localized: .noteKindFeedback)
        }
    }
}
