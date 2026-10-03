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
        let active = try Self.activeVision()
        let overdue = try active.creatingTask(title: "o", deadline: Self.day(1), by: .manager, now: Self.day(0))
        let later = try overdue.state.creatingTask(title: "l", deadline: Self.day(10), by: .manager, now: Self.day(0))
        let notifications = RecordingNotifications()

        // When
        await notifications.post(for: .player, in: later.state, now: Self.day(2)) { _ in "催促" }

        // Then
        #expect(Set(notifications.notices) == [
            NudgeNotice(nudge: .taskOverdue(overdue.taskID), message: "催促", startsAt: nil),
            NudgeNotice(nudge: .taskDueSoon(later.taskID), message: "催促", startsAt: Self.day(10 - 3)),
            NudgeNotice(nudge: .taskOverdue(later.taskID), message: "催促", startsAt: Self.day(10)),
        ])
    }
}

// MARK: - Private

private extension NudgePostingTests {
    static func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 0).addingTimeInterval(Double(offset) * 24 * 60 * 60)
    }

    static func activeVision() throws -> PartnershipState {
        let drafted = try PartnershipState()
            .establishingPairing(ownerRole: .manager)
            .draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player)
        return try drafted.state
            .proposingVision(drafted.visionID, by: .player)
            .approvingVision(drafted.visionID, by: .manager)
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
