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
    /// 未完了のタスクがあるのに、挑む人がしばらく動いていない。動かないままなら毎日出し直すので、その日の回の始まりを持つ。
    case progressReportDue(Vision.ID, on: Date)
    /// 未完了のタスクがあるのに、挑む人がしばらく動いておらず、見届ける人も声をかけていない。
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
    /// 動きがないときの催促を出す時刻（時）。
    public static let stalledReminderHour = 20
    /// 動きがないときの催促を、先の何日分まで予約するか。
    public static let stalledRemindersAhead = 7
}
