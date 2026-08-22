//
//  Nudge.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Foundation

public enum Nudge: Hashable, Sendable {
    case taskOverdue(TaskItem.ID)
    case taskDueSoon(TaskItem.ID)
    case approvalStalled(TaskItem.ID)
    case visionOverdue(Vision.ID)

    public var recipient: Role {
        switch self {
        case .taskOverdue, .taskDueSoon:      return .player
        case .approvalStalled, .visionOverdue: return .manager
        }
    }
}

extension Nudge {
    public static let dueSoonWithin: TimeInterval = 3 * 24 * 60 * 60
    public static let approvalStalledAfter: TimeInterval = 2 * 24 * 60 * 60
}
