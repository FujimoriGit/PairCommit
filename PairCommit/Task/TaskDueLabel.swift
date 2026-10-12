//
//  TaskDueLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Domain
import Foundation

extension TaskItem.Due {
    var label: String {
        switch self {
        case .overdue: String(localized: .taskDueOverdue)
        case .today: String(localized: .taskDueToday)
        case .withinWeek: String(localized: .taskDueWithinWeek)
        case .later: String(localized: .taskDueLater)
        case .unscheduled: String(localized: .commonNoDeadline)
        }
    }
}

extension [TaskItem] {
    func sortedByDeadline() -> Self {
        sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }
}
