//
//  VisionStatusText.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Domain
import Foundation

extension Vision {
    func remaining(at now: Date) -> String {
        switch countdown(at: now, in: .current) {
        case .unbounded: String(localized: .commonNoDeadline)
        case .overdue(let deadline): String(localized: .visionCardOverdue(deadline.formatted(Date.FormatStyle.yearMonthDayTime)))
        case .days(0, _): String(localized: .visionCardDueToday)
        case .days(let days, let deadline):
            String(localized: .visionCardDaysLeft(days: days, deadline.formatted(Date.FormatStyle.yearMonthDayTime)))
        }
    }

    func remainingSymbol(at now: Date) -> String {
        switch countdown(at: now, in: .current) {
        case .unbounded: "infinity"
        case .overdue: "exclamationmark.triangle.fill"
        case .days: "calendar"
        }
    }

    /// 起案から期限までのうち、過ぎた割合。期限が無ければ nil。
    func elapsed(at now: Date) -> Double? {
        switch countdown(at: now, in: .current) {
        case .unbounded: nil
        case .overdue: 1
        case .days(_, let deadline): elapsed(at: now, until: deadline)
        }
    }
}

extension Vision.Progress {
    /// タスクが1つも無ければ nil。
    var summary: String? {
        fraction.map {
            String(localized: .visionCardTaskProgress(approved, total, $0.formatted(.percent.precision(.fractionLength(0)))))
        }
    }
}

// MARK: - Private

private extension Vision {
    func elapsed(at now: Date, until deadline: Date) -> Double? {
        let span = deadline.timeIntervalSince(createdAt)
        guard span > 0 else { return nil }
        return min(max(now.timeIntervalSince(createdAt) / span, 0), 1)
    }
}
