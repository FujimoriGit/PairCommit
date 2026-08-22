//
//  NudgeTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import Foundation
import Testing

struct NudgeTests {

    @Test("期限を過ぎた未完了タスクは、実行する側が催促される")
    func overdueTaskNudgesThePlayer() throws {
        // Given
        let ready = try activeVision()
        let state = try ready.state.creatingTask(
            title: "走る",
            deadline: day(1),
            by: .manager,
            now: day(0)
        ).state

        // When
        let nudges = state.nudges(for: .player, now: day(2))

        // Then
        #expect(nudges.count == 1)
        #expect(nudges.first == .taskOverdue(state.tasks[0].id))
    }

    @Test("期限が近づいた未完了タスクは、期限前でも実行する側が催促される")
    func taskNearingItsDeadlineNudgesThePlayer() throws {
        // Given
        let ready = try activeVision()
        let state = try ready.state.creatingTask(
            title: "走る",
            deadline: day(3),
            by: .manager,
            now: day(0)
        ).state

        // When
        let nudges = state.nudges(for: .player, now: day(1))

        // Then
        #expect(nudges == [.taskDueSoon(state.tasks[0].id)])
    }

    @Test("期限のないタスクは催促されない")
    func taskWithoutDeadlineIsNeverNudged() throws {
        // Given
        let ready = try activeVision()
        let state = try ready.state.creatingTask(title: "走る", by: .manager, now: day(0)).state

        // When
        let nudges = state.nudges(for: .player, now: day(365))

        // Then
        #expect(nudges.isEmpty)
    }

    @Test("完了報告が承認されないまま滞留すると、承認する側が催促される")
    func stalledApprovalNudgesTheManager() throws {
        // Given
        let ready = try activeVision()
        let created = try ready.state.creatingTask(title: "走る", by: .manager, now: day(0))
        let reported = try created.state.reportingTask(created.taskID, by: .player, now: day(0))

        // When
        let nudges = reported.nudges(for: .manager, now: day(3))

        // Then
        #expect(nudges == [.approvalStalled(created.taskID)])
    }

    @Test("完了報告した直後は、承認する側は催促されない")
    func freshReportDoesNotNudgeTheManager() throws {
        // Given
        let ready = try activeVision()
        let created = try ready.state.creatingTask(title: "走る", by: .manager, now: day(0))
        let reported = try created.state.reportingTask(created.taskID, by: .player, now: day(0))

        // When
        let nudges = reported.nudges(for: .manager, now: day(1))

        // Then
        #expect(nudges.isEmpty)
    }

    @Test("期限を過ぎた進行中のビジョンは、達成を判断する側が催促される")
    func overdueVisionNudgesTheManager() throws {
        // Given
        let ready = try activeVision(deadline: day(1))

        // When
        let nudges = ready.state.nudges(for: .manager, now: day(2))

        // Then
        #expect(nudges == [.visionOverdue(ready.visionID)])
    }

    @Test("進行中のビジョンがなければ何も催促されない")
    func nothingIsNudgedWithoutAnActiveVision() {
        // Given
        let state = PartnershipState()

        // When / Then
        #expect(state.nudges(for: .player, now: day(365)).isEmpty)
        #expect(state.nudges(for: .manager, now: day(365)).isEmpty)
    }

    @Test("催促は相手側には渡らない")
    func aNudgeReachesOnlyItsRecipient() throws {
        // Given
        let ready = try activeVision()
        let state = try ready.state.creatingTask(
            title: "走る",
            deadline: day(1),
            by: .manager,
            now: day(0)
        ).state

        // When
        let nudges = state.nudges(for: .manager, now: day(2))

        // Then
        #expect(nudges.isEmpty)
    }
}

// MARK: - Private

private extension NudgeTests {
    func activeVision(deadline: Date? = nil) throws -> (state: PartnershipState, visionID: Vision.ID) {
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
        let drafted = try paired.draftingVision(
            statement: "s",
            doneCriteria: "c",
            deadline: deadline,
            by: .player
        )
        let proposed = try drafted.state.proposingVision(drafted.visionID, by: .player)
        return (try proposed.approvingVision(drafted.visionID, by: .manager), drafted.visionID)
    }
}

private func day(_ offset: Int) -> Date {
    Date(timeIntervalSince1970: 1_800_000_000 + Double(offset) * 24 * 60 * 60)
}
