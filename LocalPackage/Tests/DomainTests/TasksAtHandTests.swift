//
//  TasksAtHandTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Domain
import Foundation
import Testing

struct TasksAtHandTests {

    @Test("挑む人がいま手を動かすタスクに、期限が切れたか7日以内に来る未完了のタスクが入る", arguments: [
        day(-1),
        day(0, hoursLater: 3),
        day(7)
    ])
    func playerSeesTodoDueWithinAWeek(deadline: Date) throws {
        // Given
        let (state, taskID) = try todoTask(deadline: deadline)

        // When
        let tasks = state.tasksAtHand(for: .player, now: day(0), in: utc)

        // Then
        #expect(tasks.map(\.id) == [taskID])
    }

    @Test("挑む人がいま手を動かすタスクに、期限が8日後以降のタスクと、期限の無いタスクは入らない", arguments: [day(8), nil])
    func playerDoesNotSeeTodoDueLaterOrUnscheduled(deadline: Date?) throws {
        // Given
        let (state, _) = try todoTask(deadline: deadline)

        // When
        let tasks = state.tasksAtHand(for: .player, now: day(0), in: utc)

        // Then
        #expect(tasks.isEmpty)
    }

    @Test("挑む人がいま手を動かすタスクに、見届ける人の番のタスクは入らない", arguments: [TaskItem.Status.proposed, .reported])
    func playerDoesNotSeeTheManagersTurn(status: TaskItem.Status) throws {
        // Given
        let (state, _) = try paired().activeVisionWithTask(in: status)

        // When
        let tasks = state.tasksAtHand(for: .player, now: Date(), in: utc)

        // Then
        #expect(tasks.isEmpty)
    }

    @Test("見届ける人がいま手を動かすタスクに、採用待ちと承認待ちのタスクが入る", arguments: [TaskItem.Status.proposed, .reported])
    func managerSeesTasksAwaitingDecision(status: TaskItem.Status) throws {
        // Given
        let (state, taskID) = try paired().activeVisionWithTask(in: status)

        // When
        let tasks = state.tasksAtHand(for: .manager, now: Date(), in: utc)

        // Then
        #expect(tasks.map(\.id) == [taskID])
    }

    @Test("見届ける人がいま手を動かすタスクに、期限が過ぎた未完了のタスクが入る")
    func managerSeesOverdueTodo() throws {
        // Given
        let (state, taskID) = try todoTask(deadline: day(-1))

        // When
        let tasks = state.tasksAtHand(for: .manager, now: day(0), in: utc)

        // Then
        #expect(tasks.map(\.id) == [taskID])
    }

    @Test("見届ける人がいま手を動かすタスクに、期限が過ぎていない未完了のタスクは入らない", arguments: [day(0, hoursLater: 3), nil])
    func managerDoesNotSeeTodoNotYetDue(deadline: Date?) throws {
        // Given
        let (state, _) = try todoTask(deadline: deadline)

        // When
        let tasks = state.tasksAtHand(for: .manager, now: day(0), in: utc)

        // Then
        #expect(tasks.isEmpty)
    }

    @Test("いま手を動かすタスクは期限の早い順に並び、期限の無いタスクは最後になる")
    func tasksToActOnAreOrderedByDeadline() throws {
        // Given
        let (active, _) = try paired().activeVision()
        let (first, later) = try active.creatingTask(title: "later", deadline: day(5), by: .player, now: day(-1))
        let (second, unscheduled) = try first.creatingTask(title: "unscheduled", by: .player, now: day(-1))
        let (state, sooner) = try second.creatingTask(title: "sooner", deadline: day(2), by: .player, now: day(-1))

        // When
        let tasks = state.tasksAtHand(for: .manager, now: day(0), in: utc)

        // Then
        #expect(tasks.map(\.id) == [sooner, later, unscheduled])
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

private func paired() throws -> PartnershipState {
    try PartnershipState().establishingPairing(ownerRole: .manager)
}

private func todoTask(deadline: Date?) throws -> (state: PartnershipState, taskID: TaskItem.ID) {
    let (active, _) = try paired().activeVision()
    return try active.creatingTask(title: "t", deadline: deadline, by: .manager, now: day(-2))
}
