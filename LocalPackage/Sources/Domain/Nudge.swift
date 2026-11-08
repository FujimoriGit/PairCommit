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
    /// `on` は、その日の回が始まった時刻。
    case progressReportDue(Vision.ID, on: Date)
    /// `on` は、その日の回が始まった時刻。
    case checkInDue(Vision.ID, on: Date)

    public var recipient: Role {
        switch self {
        case .taskOverdue, .taskDueSoon, .progressReportDue: return .player
        case .approvalStalled, .visionOverdue, .checkInDue:  return .manager
        }
    }

    public var subject: Note.Subject {
        switch self {
        case .taskOverdue(let id), .taskDueSoon(let id), .approvalStalled(let id): .task(id)
        case .visionOverdue(let id), .progressReportDue(let id, _), .checkInDue(let id, _): .vision(id)
        }
    }
}

extension Nudge {
    public static let dueSoonWithin: TimeInterval = 3 * 24 * 60 * 60
    public static let approvalStalledAfter: TimeInterval = 2 * 24 * 60 * 60
    public static let stalledAfter: TimeInterval = 24 * 60 * 60
    public static let stalledReminderHour = 20
    public static let stalledRemindersAhead = 7
}
