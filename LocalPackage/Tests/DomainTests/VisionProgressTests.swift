//
//  VisionProgressTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/04
//

import Domain
import Foundation
import Testing

struct VisionProgressTests {

    @Test("ビジョンの進捗は、取り消しを除いたタスクのうち、完了したタスクの数で測る")
    func progressCountsCompletedTasksAmongThoseNotCancelled() throws {
        // Given
        let (active, visionID) = try PartnershipState().activeVision()
        let (withApproved, approved) = try active.creatingTask(title: "承認済み", by: .manager)
        let (withReported, reported) = try withApproved.creatingTask(title: "報告済み", by: .manager)
        let (withTodo, _) = try withReported.creatingTask(title: "todoのまま", by: .manager)
        let (withCancelled, cancelled) = try withTodo.creatingTask(title: "取り消し", by: .manager)
        let state = try withCancelled
            .reportingTask(approved, by: .player)
            .approvingTask(approved, by: .manager)
            .reportingTask(reported, by: .player)
            .cancellingTask(cancelled, by: .manager)

        // When
        let progress = state.progress(of: visionID)

        // Then
        #expect(progress.approved == 1)
        #expect(progress.total == 3)
    }

    @Test("ビジョンの進捗は、採用待ちのタスクを数えない")
    func progressIgnoresTasksAwaitingAdoption() throws {
        // Given
        let (active, visionID) = try PartnershipState().activeVision()
        let (withTodo, _) = try active.creatingTask(title: "管理者のタスク", by: .manager)
        let (state, _) = try withTodo.creatingTask(title: "プレイヤーの起案", by: .player)

        // When
        let progress = state.progress(of: visionID)

        // Then
        #expect(progress.total == 1)
    }

    @Test("タスクの無いビジョンには、進捗率がない")
    func visionWithoutTasksHasNoProgressFraction() throws {
        // Given
        let (state, visionID) = try PartnershipState().activeVision()

        // When
        let progress = state.progress(of: visionID)

        // Then
        #expect(progress.fraction == nil)
    }
}
