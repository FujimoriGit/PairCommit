//
//  TaskProgressTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import Foundation
import Testing

struct TaskProgressTests {

    @Test("見届ける人が進捗率を決めると、タスクの進捗率はその値になる")
    func managerSetsTheProgressOfATask() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When
        let updated = try state.settingProgress(40, on: taskID, by: .manager)

        // Then
        #expect(updated.tasks.first { $0.id == taskID }?.progress == 40)
    }

    @Test("挑む人は進捗率を決められない")
    func playerCannotSetTheProgress() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.settingProgress(40, on: taskID, by: .player)
        }
    }

    @Test(
        "採用待ち・完了・取り消しのタスクには、進捗率を決められない",
        arguments: [TaskItem.Status.proposed, .approved, .cancelled]
    )
    func progressCannotBeSetOutsideTheWork(status: TaskItem.Status) throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask(in: status)

        // When / Then
        #expect(throws: DomainError.invalidTaskTransition(from: status)) {
            try state.settingProgress(40, on: taskID, by: .manager)
        }
    }

    @Test("0%から100%の外の進捗率は決められない", arguments: [-10, 110])
    func progressOutsideZeroToHundredIsRefused(percent: Int) throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        #expect(throws: DomainError.progressOutOfRange) {
            try state.settingProgress(percent, on: taskID, by: .manager)
        }
    }

    @Test("見届ける人が進捗率を変えると、挑む人に新しい進捗率が知らされる")
    func changedProgressIsToldToThePlayer() throws {
        // Given
        let (before, taskID) = try PartnershipState().activeVisionWithTask()
        let after = try before.settingProgress(60, on: taskID, by: .manager)

        // When
        let actions = after.partnerActions(since: before, for: .player)

        // Then
        #expect(actions == [.progressChanged(taskID, 60)])
    }

    @Test("進捗率が決まっているタスクを見届ける人が承認すると、挑む人には承認だけが知らされる")
    func approvalOfATaskWithProgressIsToldWithoutTheProgress() throws {
        // Given
        let (todo, taskID) = try PartnershipState().activeVisionWithTask()
        let before = try todo
            .settingProgress(60, on: taskID, by: .manager)
            .reportingTask(taskID, by: .player)
        let after = try before.approvingTask(taskID, by: .manager)

        // When
        let actions = after.partnerActions(since: before, for: .player)

        // Then
        #expect(actions == [.taskApproved(taskID)])
    }
}
