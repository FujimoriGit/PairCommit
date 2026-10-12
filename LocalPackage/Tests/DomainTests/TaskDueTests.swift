//
//  TaskDueTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Domain
import Foundation
import Testing

struct TaskDueTests {

    @Test("期限の当日でも期限の時刻を過ぎたタスクは期限切れになり、挑む人には期限切れの催促が届く")
    func taskPastItsDeadlineTimeOnTheDayIsOverdueAndThePlayerIsNudged() throws {
        // Given
        let state = try stateWithTask(deadline: day(0, hoursLater: 10))
        let task = try #require(state.tasks.first)
        let now = day(0, hoursLater: 11)

        // When
        let due = task.due(at: now, in: utc)

        // Then
        #expect(due == .overdue)
        #expect(state.nudges(for: .player, now: now) == [.taskOverdue(task.id)])
    }

    @Test("期限の時刻より前なら、期限が当日のタスクは今日の期限になる")
    func beforeTheDeadlineTimeOnTheDayIsToday() {
        // Given
        let task = task(deadline: day(0, hoursLater: 10))

        // When
        let due = task.due(at: day(0, hoursLater: 1), in: utc)

        // Then
        #expect(due == .today)
    }

    @Test("期限が翌日から7日後の日付までのタスクは、時刻にかかわらず7日以内になる", arguments: [
        (day(1, hoursLater: -7), day(0, hoursLater: 15)),
        (day(7, hoursLater: 15), day(0, hoursLater: -7))
    ])
    func deadlineFromTomorrowToSevenDaysLaterIsWithinWeek(deadline: Date, now: Date) {
        // Given
        let task = task(deadline: deadline)

        // When
        let due = task.due(at: now, in: utc)

        // Then
        #expect(due == .withinWeek)
    }

    @Test("期限が8日後の日付より先のタスクは、それより先になる")
    func deadlineEightDaysLaterIsLater() {
        // Given
        let task = task(deadline: day(8, hoursLater: -7))

        // When
        let due = task.due(at: day(0, hoursLater: 15), in: utc)

        // Then
        #expect(due == .later)
    }

    @Test("期限の無いタスクは、期限なしになる")
    func taskWithoutDeadlineIsUnscheduled() {
        // Given
        let task = task(deadline: nil)

        // When
        let due = task.due(at: day(0), in: utc)

        // Then
        #expect(due == .unscheduled)
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

private func task(deadline: Date?) -> TaskItem {
    .init(
        id: UUID(),
        visionID: UUID(),
        title: "t",
        detail: nil,
        status: .todo,
        createdBy: .manager,
        reaction: nil,
        deadline: deadline,
        createdAt: day(-10),
        statusChangedAt: day(-10)
    )
}

private func stateWithTask(deadline: Date) throws -> PartnershipState {
    let (active, _) = try PartnershipState().establishingPairing(ownerRole: .manager).activeVision()
    return try active.creatingTask(title: "t", deadline: deadline, by: .manager, now: day(-1)).state
}
