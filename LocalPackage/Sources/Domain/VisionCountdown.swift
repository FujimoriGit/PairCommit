//
//  VisionCountdown.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/19
//

import Foundation

extension Vision {
    public enum Countdown: Equatable, Sendable {
        case unbounded
        case overdue(Date)
        case days(Int, until: Date)
    }

    /// 期限当日は、期限の時刻を過ぎるまで `.days(0, until:)`、過ぎたら `.overdue`。
    public func countdown(at now: Date, in calendar: Calendar) -> Countdown {
        guard let deadline else { return .unbounded }
        guard !isOverdue(at: now) else { return .overdue(deadline) }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: deadline)
        ).day ?? 0
        return .days(days, until: deadline)
    }

    func isOverdue(at now: Date) -> Bool {
        deadline.map { $0 < now } ?? false
    }
}
