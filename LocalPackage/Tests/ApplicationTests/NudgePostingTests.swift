//
//  NudgePostingTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Application
import Domain
import Foundation
import Testing

@MainActor
struct NudgePostingTests {

    @Test("始まっている催促はすぐ、これから始まる催促は始まる時刻に通知する")
    func postsCurrentNudgesNowAndUpcomingOnesWhenTheyStart() async throws {
        // Given
        let state = try Self.stateWithTasks(dueInDays: [1, 10])
        let now = Self.day(2)
        let notifications = RecordingNotifications()

        // When
        await notifications.post(for: .player, in: state, now: now) { _ in "催促" }

        // Then
        let current = state.nudges(for: .player, now: now).map {
            NudgeNotice(nudge: $0, message: "催促", startsAt: nil)
        }
        let upcoming = state.upcomingNudges(for: .player, now: now).map {
            NudgeNotice(nudge: $0.key, message: "催促", startsAt: $0.value)
        }
        #expect(!current.isEmpty && !upcoming.isEmpty)
        #expect(Set(notifications.notices) == Set(current + upcoming))
    }
}

// MARK: - Private

private extension NudgePostingTests {
    static func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 0).addingTimeInterval(Double(offset) * 24 * 60 * 60)
    }

    static func stateWithTasks(dueInDays days: [Int]) throws -> PartnershipState {
        let drafted = try PartnershipState()
            .establishingPairing(ownerRole: .manager)
            .draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player)
        let active = try drafted.state
            .proposingVision(drafted.visionID, by: .player)
            .approvingVision(drafted.visionID, by: .manager)
        return try days.reduce(active) { state, offset in
            try state.creatingTask(title: "t\(offset)", deadline: day(offset), by: .manager, now: day(0)).state
        }
    }
}

@MainActor
private final class RecordingNotifications: NudgeNotifying {
    private(set) var notices: [NudgeNotice] = []

    func requestPermission() async {}

    func replace(with notices: [NudgeNotice], now: Date) async {
        self.notices = notices
    }

    func withdrawAll() async {}
}
