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

    @Test("期限を過ぎた未完了のタスクは、挑む人に催促される")
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

    @Test("期限が近づいた未完了のタスクは、期限の前でも挑む人に催促される")
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

    @Test("完了の報告が承認されないまま日が経つと、見届ける人に催促される")
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

    @Test("完了を報告した直後は、見届ける人に催促されない")
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

    @Test("進行中のビジョンが期限を過ぎると、達成したかの判断を見届ける人に催促される")
    func overdueVisionNudgesTheManager() throws {
        // Given
        let ready = try activeVision(deadline: day(1))

        // When
        let nudges = ready.state.nudges(for: .manager, now: day(2))

        // Then
        #expect(nudges == [.visionOverdue(ready.visionID)])
    }

    @Test("進行中のビジョンがなければ、だれにも何も催促されない", arguments: Role.allCases)
    func nothingIsNudgedWithoutAVisionInProgress(role: Role) {
        // Given
        let state = PartnershipState()

        // When
        let nudges = state.nudges(for: role, now: day(365))

        // Then
        #expect(nudges.isEmpty)
    }

    @Test("挑む人への催促は、見届ける人には届かない")
    func playersNudgeDoesNotReachTheManager() throws {
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

    @Test("期限が近づいた催促は、予約された時刻の前には出ず、過ぎると出る")
    func dueSoonNudgeAppearsOnceItsScheduledTimePasses() throws {
        // Given
        let ready = try activeVision()
        let state = try ready.state.creatingTask(
            title: "走る",
            deadline: day(5),
            by: .manager,
            now: day(0)
        ).state
        let nudge = Nudge.taskDueSoon(state.tasks[0].id)

        // When
        let startsAt = try #require(state.upcomingNudges(for: .player, now: day(0))[nudge])

        // Then
        #expect(!state.nudges(for: .player, now: startsAt.addingTimeInterval(-1)).contains(nudge))
        #expect(state.nudges(for: .player, now: startsAt.addingTimeInterval(1)).contains(nudge))
    }

    @Test("期限を過ぎた催促は、予約された時刻の前には出ず、過ぎると出る")
    func overdueNudgeAppearsOnceItsScheduledTimePasses() throws {
        // Given
        let ready = try activeVision()
        let state = try ready.state.creatingTask(
            title: "走る",
            deadline: day(5),
            by: .manager,
            now: day(0)
        ).state
        let nudge = Nudge.taskOverdue(state.tasks[0].id)

        // When
        let startsAt = try #require(state.upcomingNudges(for: .player, now: day(0))[nudge])

        // Then
        #expect(!state.nudges(for: .player, now: startsAt.addingTimeInterval(-1)).contains(nudge))
        #expect(state.nudges(for: .player, now: startsAt.addingTimeInterval(1)).contains(nudge))
    }

    @Test("すでに出ている催促は、あとから届く催促に入らない")
    func aNudgeAlreadyInEffectIsNotUpcoming() throws {
        // Given
        let ready = try activeVision()
        let state = try ready.state.creatingTask(
            title: "走る",
            deadline: day(5),
            by: .manager,
            now: day(0)
        ).state
        let taskID = state.tasks[0].id

        // When
        let upcoming = state.upcomingNudges(for: .player, now: day(3))

        // Then
        #expect(Set(upcoming.keys) == [.taskOverdue(taskID)])
    }

    @Test("催促が始まるちょうどその瞬間でも、催促は抜け落ちず、二重にも出ない")
    func theStartingInstantIsNeitherLostNorDoubled() throws {
        // Given
        let ready = try activeVision(deadline: day(1))

        // When
        let upcoming = ready.state.upcomingNudges(for: .manager, now: day(1))
        let nudges = ready.state.nudges(for: .manager, now: day(1))

        // Then
        #expect(upcoming[.visionOverdue(ready.visionID)] != nil)
        #expect(nudges.isEmpty)
    }
}

// MARK: - Private

private extension NudgeTests {
    func activeVision(deadline: Date? = nil) throws -> (state: PartnershipState, visionID: Vision.ID) {
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
        let drafted = try paired.draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: deadline, why: nil), by: .player, now: day(0)
        )
        let proposed = try drafted.state.proposingVision(drafted.visionID, by: .player, now: day(0))
        return (try proposed.approvingVision(drafted.visionID, by: .manager, now: day(0)), drafted.visionID)
    }
}

private func day(_ offset: Int) -> Date {
    Date(timeIntervalSince1970: 1_800_000_000 + Double(offset) * 24 * 60 * 60)
}
