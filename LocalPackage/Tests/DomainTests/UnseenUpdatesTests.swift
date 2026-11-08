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
        // Given
        let (before, taskID) = try PartnershipState().activeVisionWithTask()
        let after = try before
            .reportingTask(taskID, by: .player)
            .writingNote("今週は2回行けた", on: .task(taskID), by: .player)
        let actions = after.partnerActions(since: before, for: .manager)

        // When
        let unseen = UnseenUpdates().adding(actions)

        // Then
        #expect(unseen.count(on: .task(taskID)) == 2)
    }

    @Test("タスクを開くと、そのタスクの更新だけがまだ見ていない更新から外れる")
    func openingATaskClearsOnlyItsUpdates() throws {
        // Given
        let (state, opened) = try PartnershipState().activeVisionWithTask(title: "a")
        let (_, other) = try state.creatingTask(title: "b", by: .manager)
        let unseen = UnseenUpdates().adding([.taskReported(opened), .taskReported(other)])

        // When
        let seen = unseen.seeing([.task(opened)])

        // Then
        #expect(seen.count(on: .task(opened)) == 0)
        #expect(seen.count(on: .task(other)) == 1)
    }

    @Test("挑む人が差し戻されたビジョンを取り下げると、その差し戻しはまだ見ていない更新に残らない")
    func discardedVisionLeavesNoUnseenUpdate() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()
        let returned = try proposed.rejectingVision(visionID, feedback: "期限を決めてほしい", by: .manager)
        let unseen = UnseenUpdates().adding(returned.partnerActions(since: proposed, for: .player))
        let discarded = try returned.discardingVision(visionID, by: .player)

        // When
        let kept = unseen.keeping(in: discarded)

        // Then
        #expect(kept.count(on: .vision(visionID)) == 0)
    }
}
