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

    @Test("ビジョンの進捗は、取り消したものを除いたタスクのうち、承認されたものの数で測る")
    func progressCountsApprovedTasksAmongThoseNotCancelled() throws {
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

    @Test("タスクの無いビジョンには、進捗率が無い")
    func visionWithoutTasksHasNoProgressFraction() throws {
        // Given
        let (state, visionID) = try PartnershipState().activeVision()

        // When
        let progress = state.progress(of: visionID)

        // Then
        #expect(progress.fraction == nil)
    }
}
