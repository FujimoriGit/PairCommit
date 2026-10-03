//
//  NudgePosting.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Domain
import Foundation

extension NudgeNotifying {
    /// その役割に始まっている催促はすぐ、これから始まる催促は始まる時刻に通知する。
    public func post(
        for role: Role,
        in state: PartnershipState,
        now: Date = .now,
        message: @Sendable (Nudge) -> String
    ) async {
        let current = state.nudges(for: role, now: now).map {
            NudgeNotice(nudge: $0, message: message($0), startsAt: nil)
        }
        let upcoming = state.upcomingNudges(for: role, now: now).map {
            NudgeNotice(nudge: $0.key, message: message($0.key), startsAt: $0.value)
        }
        await replace(with: current + upcoming, now: now)
    }
}
