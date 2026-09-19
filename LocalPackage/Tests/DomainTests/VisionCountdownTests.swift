//
//  VisionCountdownTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/19
//

import Domain
import Foundation
import Testing

struct VisionCountdownTests {

    @Test("期限の時刻を過ぎたら、期限当日でも期限切れになり、催促と食い違わない")
    func passingTheDeadlineTimeOnTheDayIsOverdueLikeTheNudge() throws {
        // Given
        let deadline = at(day: 0, hour: 18)
        let now = at(day: 0, hour: 19)
        let state = try activeState(deadline: deadline)
        let vision = try #require(state.activeVision)

        // When
        let countdown = vision.countdown(at: now, in: utc)

        // Then
        #expect(countdown == .overdue)
        #expect(state.nudges(for: .manager, now: now) == [.visionOverdue(vision.id)])
    }

    @Test("期限の時刻より前なら、期限当日は残り0日になる")
    func beforeTheDeadlineTimeOnTheDayLeavesZeroDays() {
        // Given
        let vision = vision(deadline: at(day: 0, hour: 18))

        // When
        let countdown = vision.countdown(at: at(day: 0, hour: 9), in: utc)

        // Then
        #expect(countdown == .days(0))
    }

    @Test("残り日数は時刻ではなく日付の差で数える")
    func remainingDaysCountCalendarDaysNotElapsedTime() {
        // Given
        let vision = vision(deadline: at(day: 2, hour: 1))

        // When
        let countdown = vision.countdown(at: at(day: 0, hour: 23), in: utc)

        // Then
        #expect(countdown == .days(2))
    }

    @Test("期限の無いビジョンは数えない")
    func visionWithoutDeadlineIsUnbounded() {
        // Given
        let vision = vision(deadline: nil)

        // When
        let countdown = vision.countdown(at: at(day: 0, hour: 0), in: utc)

        // Then
        #expect(countdown == .unbounded)
    }
}

// MARK: - Private

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

// 2027-01-15 00:00 UTC
private func at(day: Int, hour: Int) -> Date {
    Date(timeIntervalSince1970: 1_800_000_000 - 8 * 60 * 60 + Double(day * 24 + hour) * 60 * 60)
}

private func vision(deadline: Date?) -> Vision {
    .init(
        id: UUID(),
        statement: "s",
        doneCriteria: "c",
        deadline: deadline,
        why: nil,
        status: .active,
        createdAt: at(day: -10, hour: 0)
    )
}

private func activeState(deadline: Date) throws -> PartnershipState {
    let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
    let drafted = try paired.draftingVision(statement: "s", doneCriteria: "c", deadline: deadline, by: .player)
    let proposed = try drafted.state.proposingVision(drafted.visionID, by: .player)
    return try proposed.approvingVision(drafted.visionID, by: .manager)
}
