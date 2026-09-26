//
//  TaskLifecycleTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/26
//

import Domain
import Foundation
import Testing

struct TaskLifecycleTests {

    @Test("管理者が作るタスクは todo から、プレイヤー起案は proposed（採用待ち）から始まる")
    func taskStartsAsTodoForManagerAndProposedForPlayer() throws {
        // Given
        let (active, _) = try PartnershipState().activeVision()

        // When
        let (withManagerTask, byManager) = try active.creatingTask(title: "管理者生成", by: .manager)
        let (state, byPlayer) = try withManagerTask.creatingTask(title: "プレイヤー起案", by: .player)

        // Then
        #expect(state.status(of: byManager) == .todo)
        #expect(state.status(of: byPlayer) == .proposed)
    }

    @Test("タスクは active なビジョンの下にしか作れない（孤立タスクは存在しない）")
    func taskCannotBeCreatedWithoutActiveVision() {
        // Given
        let state = PartnershipState()

        // When / Then
        #expect(throws: DomainError.noActiveVision) {
            try state.creatingTask(title: "孤立タスク", by: .manager)
        }
    }

    @Test("プレイヤーが完了報告し、管理者が承認して初めてタスクは完了になる")
    func taskCompletesOnlyThroughReportThenApproval() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        let reported = try state.reportingTask(taskID, by: .player)
        #expect(reported.status(of: taskID) == .reported)

        let approved = try reported.approvingTask(taskID, by: .manager)
        #expect(approved.status(of: taskID) == .approved)
    }

    @Test("完了報告はプレイヤーだけ、完了承認は管理者だけができる（役割の非対称性）")
    func reportingIsPlayersJobAndApprovalIsManagersJob() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.reportingTask(taskID, by: .manager)
        }
        let reported = try state.reportingTask(taskID, by: .player)
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try reported.approvingTask(taskID, by: .player)
        }
    }

    @Test("管理者はプレイヤー起案のタスクを採用して todo にできる")
    func managerCanAdoptPlayerProposedTask() throws {
        // Given
        let (active, _) = try PartnershipState().activeVision()
        let (proposed, taskID) = try active.creatingTask(title: "起案", by: .player)

        // When
        let state = try proposed.adoptingTask(taskID, by: .manager)

        // Then
        #expect(state.status(of: taskID) == .todo)
    }

    @Test("管理者は完了報告を差し戻して todo に戻せる（やり直しの指示）")
    func managerCanReturnReportedTaskToTodo() throws {
        // Given
        let (created, taskID) = try PartnershipState().activeVisionWithTask()
        let reported = try created.reportingTask(taskID, by: .player)

        // When
        let state = try reported.returningTask(taskID, by: .manager)

        // Then
        #expect(state.status(of: taskID) == .todo)
    }

    @Test("管理者は未完了タスクを取り下げられるが、承認済み（完了）は取り消せない")
    func managerCanCancelOpenTasksButNotApprovedOnes() throws {
        // Given
        let (withOpen, openTask) = try PartnershipState().activeVisionWithTask(title: "未完了")
        let (withDone, doneTask) = try withOpen.creatingTask(title: "完了", by: .manager)
        let ready = try withDone
            .reportingTask(doneTask, by: .player)
            .approvingTask(doneTask, by: .manager)

        // When
        let state = try ready.cancellingTask(openTask, by: .manager)

        // Then
        #expect(state.status(of: openTask) == .cancelled)
        #expect(throws: DomainError.invalidTaskTransition(from: .approved)) {
            try state.cancellingTask(doneTask, by: .manager)
        }
    }

    @Test("完了報告を経ないタスクは承認できない（todo からの直接承認は不可）")
    func todoTaskCannotBeApprovedWithoutReport() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        #expect(throws: DomainError.invalidTaskTransition(from: .todo)) {
            try state.approvingTask(taskID, by: .manager)
        }
    }

    @Test("タスクの名前は、空白だけでは作れない")
    func taskCannotBeCreatedWithBlankTitle() throws {
        // Given
        let (state, _) = try PartnershipState().activeVision()

        // When / Then
        #expect(throws: DomainError.blankText) {
            try state.creatingTask(title: "　", by: .manager)
        }
    }
}
