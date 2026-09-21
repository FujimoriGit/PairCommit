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
        let deadline = day(0, hoursLater: 10)
        let now = day(0, hoursLater: 11)
        let state = try activeState(deadline: deadline)
        let vision = try #require(state.activeVision)

        // When
        let countdown = vision.countdown(at: now, in: utc)

        // Then
        #expect(countdown == .overdue(deadline))
        #expect(state.nudges(for: .manager, now: now) == [.visionOverdue(vision.id)])
    }

    @Test("期限の時刻より前なら、期限当日は残り0日になる")
    func beforeTheDeadlineTimeOnTheDayLeavesZeroDays() {
        // Given
        let deadline = day(0, hoursLater: 10)
        let vision = vision(deadline: deadline)

        // When
        let countdown = vision.countdown(at: day(0, hoursLater: 1), in: utc)

        // Then
        #expect(countdown == .days(0, until: deadline))
    }

    @Test("残り日数は時刻ではなく日付の差で数える")
    func remainingDaysCountCalendarDaysNotElapsedTime() {
        // Given
        let deadline = day(2, hoursLater: -7)
        let vision = vision(deadline: deadline)

        // When
        let countdown = vision.countdown(at: day(0, hoursLater: 15), in: utc)

        // Then
        #expect(countdown == .days(2, until: deadline))
    }

    @Test("期限の無いビジョンは数えない")
    func visionWithoutDeadlineIsUnbounded() {
        // Given
        let vision = vision(deadline: nil)

        // When
        let countdown = vision.countdown(at: day(0), in: utc)

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

// 2027-01-15 08:00 UTC
private func day(_ offset: Int, hoursLater hours: Int = 0) -> Date {
    Date(timeIntervalSince1970: 1_800_000_000 + Double(offset * 24 + hours) * 60 * 60)
}

private func vision(deadline: Date?) -> Vision {
    .init(
        id: UUID(),
        statement: "s",
        doneCriteria: "c",
        deadline: deadline,
        why: nil,
        status: .active,
        createdAt: day(-10)
    )
}

private func activeState(deadline: Date) throws -> PartnershipState {
    let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
    let drafted = try paired.draftingVision(statement: "s", doneCriteria: "c", deadline: deadline, by: .player)
    let proposed = try drafted.state.proposingVision(drafted.visionID, by: .player)
    return try proposed.approvingVision(drafted.visionID, by: .manager)
}
