//
//  PartnerActionTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import Foundation
import Testing

struct PartnerActionTests {

    @Test("挑む人がタスクの完了を報告すると、見届ける人に完了報告が知らされる")
    func reportByThePlayerIsToldToTheManager() throws {
        // Given
        let (before, taskID) = try PartnershipState().activeVisionWithTask()
        let after = try before.reportingTask(taskID, by: .player)

        // When
        let actions = after.partnerActions(since: before, for: .manager)

        // Then
        #expect(actions == [.taskReported(taskID)])
    }

    @Test("自分の操作は、自分には知らされない")
    func ownActionIsNotToldToOneself() throws {
        // Given
        let (before, taskID) = try PartnershipState().activeVisionWithTask()
        let after = try before.reportingTask(taskID, by: .player)

        // When
        let actions = after.partnerActions(since: before, for: .player)

        // Then
        #expect(actions.isEmpty)
    }

    @Test("挑む人がビジョンを提出すると、見届ける人に提出が知らされる")
    func submittedVisionIsToldToTheManager() throws {
        // Given
        let before = PartnershipState()
        let (after, visionID) = try before.proposedVision()

        // When
        let actions = after.partnerActions(since: before, for: .manager)

        // Then
        #expect(actions == [.visionProposed(visionID)])
    }

    @Test("見届ける人がビジョンを差し戻すと、挑む人に差し戻しが知らされる")
    func returnedVisionIsToldToThePlayer() throws {
        // Given
        let (before, visionID) = try PartnershipState().proposedVision()
        let after = try before.rejectingVision(visionID, by: .manager)

        // When
        let actions = after.partnerActions(since: before, for: .player)

        // Then
        #expect(actions == [.visionReturned(visionID)])
    }

    @Test("見届ける人がタスクを追加すると、挑む人に追加が知らされる")
    func addedTaskIsToldToThePlayer() throws {
        // Given
        let (before, _) = try PartnershipState().activeVision()
        let (after, taskID) = try before.creatingTask(title: "走る", by: .manager)

        // When
        let actions = after.partnerActions(since: before, for: .player)

        // Then
        #expect(actions == [.taskAdded(taskID)])
    }

    @Test("見届ける人が完了報告を差し戻すと、挑む人に差し戻しが知らされる")
    func returnedReportIsToldToThePlayer() throws {
        // Given
        let (todo, taskID) = try PartnershipState().activeVisionWithTask()
        let before = try todo.reportingTask(taskID, by: .player)
        let after = try before.returningTask(taskID, by: .manager)

        // When
        let actions = after.partnerActions(since: before, for: .player)

        // Then
        #expect(actions == [.taskReturned(taskID)])
    }

    @Test("見届ける人がタスクを取り消すと、挑む人に取り消しが知らされる")
    func cancelledTaskIsToldToThePlayer() throws {
        // Given
        let (before, taskID) = try PartnershipState().activeVisionWithTask()
        let after = try before.cancellingTask(taskID, by: .manager)

        // When
        let actions = after.partnerActions(since: before, for: .player)

        // Then
        #expect(actions == [.taskCancelled(taskID)])
    }

    @Test("見届ける人がビジョンを閉じると、挑む人には閉じたことだけが知らされる")
    func closingVisionIsToldWithoutEachCancelledTask() throws {
        // Given
        let (active, visionID) = try PartnershipState().activeVision()
        let before = try active.creatingTask(title: "走る", by: .manager).state
        let after = try before.closingVision(visionID, as: .abandoned, by: .manager)

        // When
        let actions = after.partnerActions(since: before, for: .player)

        // Then
        #expect(actions == [.visionClosed(visionID, .abandoned)])
    }

    @Test("挑む人がタスクに感情を付けると、見届ける人にその感情が知らされる")
    func reactionIsToldToTheManager() throws {
        // Given
        let (before, taskID) = try PartnershipState().activeVisionWithTask()
        let after = try before.settingReaction(.uneasy, on: taskID, by: .player)

        // When
        let actions = after.partnerActions(since: before, for: .manager)

        // Then
        #expect(actions == [.reactionChanged(taskID, .uneasy)])
    }

    @Test("挑む人がタスクの感情を外しても、見届ける人には知らされない")
    func removedReactionIsNotTold() throws {
        // Given
        let (todo, taskID) = try PartnershipState().activeVisionWithTask()
        let before = try todo.settingReaction(.angry, on: taskID, by: .player)
        let after = try before.settingReaction(nil, on: taskID, by: .player)

        // When
        let actions = after.partnerActions(since: before, for: .manager)

        // Then
        #expect(actions.isEmpty)
    }

    @Test("相手の操作が続けて届くと、それぞれが知らされる")
    func consecutiveActionsAreAllTold() throws {
        // Given
        let (before, visionID) = try PartnershipState().proposedVision()
        let (after, taskID) = try before
            .approvingVision(visionID, by: .manager)
            .creatingTask(title: "走る", by: .manager)

        // When
        let actions = after.partnerActions(since: before, for: .player)

        // Then
        #expect(actions == [.visionApproved(visionID), .taskAdded(taskID)])
    }

    @Test("別のペアの状態と比べると、何も知らされない")
    func stateOfAnotherPairTellsNothing() throws {
        // Given
        let before = try PartnershipState().establishingPairing(ownerRole: .manager)
        let after = try PartnershipState().establishingPairing(ownerRole: .manager).proposedVision().state

        // When
        let actions = after.partnerActions(since: before, for: .manager)

        // Then
        #expect(actions.isEmpty)
    }
}
