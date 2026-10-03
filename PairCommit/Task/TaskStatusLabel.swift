//
//  TaskStatusLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import SwiftUI

extension TaskItem.Status {
    var label: String {
        switch self {
        case .proposed: String(localized: .taskStatusProposed)
        case .todo: String(localized: .taskStatusTodo)
        case .reported: String(localized: .commonAwaitingApproval)
        case .approved: String(localized: .taskStatusApproved)
        case .cancelled: String(localized: .taskStatusCancelled)
        }
    }

    var tint: Color {
        switch self {
        case .proposed, .reported: .orange
        case .approved: .green
        case .todo, .cancelled: .secondary
        }
    }
}
