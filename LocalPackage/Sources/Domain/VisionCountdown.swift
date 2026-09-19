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
        case overdue
        case days(Int)
    }

    /// 期限切れは催促と同じく時刻で判定し、残り日数は `calendar` の日付の差で数える。
    public func countdown(at now: Date, in calendar: Calendar) -> Countdown {
        guard let deadline else { return .unbounded }
        guard !isOverdue(at: now) else { return .overdue }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: deadline)
        ).day ?? 0
        return .days(days)
    }

    func isOverdue(at now: Date) -> Bool {
        deadline.map { $0 < now } ?? false
    }
}
