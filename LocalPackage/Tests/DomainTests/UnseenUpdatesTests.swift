//
//  UnseenUpdatesTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Domain
import Foundation
import Testing

struct UnseenUpdatesTests {

    @Test("挑む人が完了を報告して書き込むと、見届ける人にはそのタスクのまだ見ていない更新が2件になる")
    func reportAndNoteAreTwoUnseenUpdatesOnTheTask() throws {
        let (before, taskID) = try PartnershipState().activeVisionWithTask()
        let after = try before
            .reportingTask(taskID, by: .player)
            .writingNote("今週は2回行けた", on: .task(taskID), by: .player)
        let actions = after.partnerActions(since: before, for: .manager)

        let unseen = UnseenUpdates().adding(actions)

        #expect(unseen.count(on: .task(taskID)) == 2)
    }

    @Test("タスクを開くと、そのタスクの更新だけがまだ見ていない更新から外れる")
    func openingATaskClearsOnlyItsUpdates() throws {
        let (state, opened) = try PartnershipState().activeVisionWithTask(title: "a")
        let (_, other) = try state.creatingTask(title: "b", by: .manager)
        let unseen = UnseenUpdates().adding([.taskReported(opened), .taskReported(other)])

        let seen = unseen.seeing([.task(opened)])

        #expect(seen.count(on: .task(opened)) == 0)
        #expect(seen.count(on: .task(other)) == 1)
    }

    @Test("挑む人が差し戻されたビジョンを取り下げると、その差し戻しはまだ見ていない更新に残らない")
    func discardedVisionLeavesNoUnseenUpdate() throws {
        let (proposed, visionID) = try PartnershipState().proposedVision()
        let returned = try proposed.rejectingVision(visionID, feedback: "期限を決めてほしい", by: .manager)
        let unseen = UnseenUpdates().adding(returned.partnerActions(since: proposed, for: .player))
        let discarded = try returned.discardingVision(visionID, by: .player)

        let kept = unseen.keeping(in: discarded)

        #expect(kept.count(on: .vision(visionID)) == 0)
    }

    @Test("挑む人がビジョンを提出すると、見届ける人のまだ見ていない更新はビジョンの分に数えられる")
    func submittedVisionCountsAsAnOpenVision() throws {
        let before = PartnershipState()
        let (after, _) = try before.proposedVision()
        let unseen = UnseenUpdates().adding(after.partnerActions(since: before, for: .manager))

        let count = unseen.count(in: .openVisions, of: after)

        #expect(count == 1)
    }

    @Test("見届ける人がビジョンを達成にすると、挑む人のまだ見ていない更新は閉じたビジョンの分に数えられる")
    func closedVisionCountsAsClosed() throws {
        let (before, visionID) = try PartnershipState().activeVision()
        let after = try before.closingVision(visionID, as: .achieved, by: .manager)
        let unseen = UnseenUpdates().adding(after.partnerActions(since: before, for: .player))

        let count = unseen.count(in: .closedVisions, of: after)

        #expect(count == 1)
    }

    @Test("進行中のビジョンのタスクのまだ見ていない更新は、タスクの分に数えられる")
    func taskOfTheActiveVisionCountsAsAnOpenTask() throws {
        let (state, taskID) = try PartnershipState().activeVisionWithTask()
        let unseen = UnseenUpdates().adding([.taskReported(taskID)])

        let count = unseen.count(in: .openTasks, of: state)

        #expect(count == 1)
    }

    @Test("ビジョンが閉じると、そのタスクのまだ見ていない更新は閉じたビジョンの分に数えられる")
    func taskOfAClosedVisionCountsAsClosed() throws {
        let (state, taskID) = try PartnershipState().activeVisionWithTask()
        let visionID = try #require(state.activeVision?.id)
        let closed = try state.closingVision(visionID, as: .achieved, by: .manager)
        let unseen = UnseenUpdates().adding([.taskReported(taskID)])

        let count = unseen.count(in: .closedVisions, of: closed)

        #expect(count == 1)
    }
}
