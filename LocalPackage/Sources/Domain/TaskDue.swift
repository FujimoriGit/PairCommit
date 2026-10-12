//
//  TaskDue.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Foundation

extension TaskItem {
    public enum Due: Hashable, Sendable {
        case overdue
        case today
        case withinWeek
        case later
        case unscheduled
    }

    /// 期限の当日は、期限の時刻を過ぎるまで `.today`、過ぎたら `.overdue`。
    /// 翌日から7日後の日付までは `.withinWeek`。
    public func due(at now: Date, in calendar: Calendar) -> Due {
        guard let deadline else { return .unscheduled }
        guard deadline >= now else { return .overdue }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: deadline)
        ).day ?? 0
        switch days {
        case ...0: return .today
        case 1...7: return .withinWeek
        default: return .later
        }
    }
}
