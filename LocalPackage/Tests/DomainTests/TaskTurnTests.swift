//
//  TaskTurnTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Domain
import Foundation
import Testing

struct TaskTurnTests {

    @Test("挑む人が起案したタスクと、完了を報告したタスクは、見届ける人の番になる", arguments: [TaskItem.Status.proposed, .reported])
    func proposedOrReportedTaskIsTheManagersTurn(status: TaskItem.Status) throws {
        // Given
        let (state, taskID) = try PartnershipState().establishingPairing(ownerRole: .manager).activeVisionWithTask(in: status)

        // When
        let turn = state.status(of: taskID)?.turn

        // Then
        #expect(turn == .manager)
    }

    @Test("見届ける人が採用したタスクは、挑む人の番になる")
    func adoptedTaskIsThePlayersTurn() throws {
        // Given
        let (state, taskID) = try PartnershipState().establishingPairing(ownerRole: .manager).activeVisionWithTask(in: .todo)

        // When
        let turn = state.status(of: taskID)?.turn

        // Then
        #expect(turn == .player)
    }

    @Test("見届ける人が差し戻したタスクは、挑む人の番になる")
    func returnedTaskIsThePlayersTurn() throws {
        // Given
        let (reported, taskID) = try PartnershipState().establishingPairing(ownerRole: .manager).activeVisionWithTask(in: .reported)
        let state = try reported.returningTask(taskID, feedback: "やり直して", by: .manager)

        // When
        let turn = state.status(of: taskID)?.turn

        // Then
        #expect(turn == .player)
    }

    @Test("承認したタスクと取り消したタスクは、どちらの番でもない", arguments: [TaskItem.Status.approved, .cancelled])
    func closedTaskIsNobodysTurn(status: TaskItem.Status) throws {
        // Given
        let (state, taskID) = try PartnershipState().establishingPairing(ownerRole: .manager).activeVisionWithTask(in: status)

        // When
        let turn = state.status(of: taskID)?.turn

        // Then
        #expect(turn == nil)
    }
}

