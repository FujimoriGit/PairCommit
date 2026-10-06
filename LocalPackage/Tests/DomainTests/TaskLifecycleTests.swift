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

    @Test("管理者が作ったタスクはすぐ未完了として並び、プレイヤーが起案したタスクは採用待ちになる")
    func managersTaskIsReadyAtOnceWhilePlayersProposalAwaitsAdoption() throws {
        // Given
        let (active, _) = try PartnershipState().activeVision()

        // When
        let (withManagerTask, byManager) = try active.creatingTask(title: "管理者生成", by: .manager)
        let (state, byPlayer) = try withManagerTask.creatingTask(title: "プレイヤー起案", by: .player)

        // Then
        #expect(state.status(of: byManager) == .todo)
        #expect(state.status(of: byPlayer) == .proposed)
    }

    @Test("タスクは進行中のビジョンの下にしか作れない")
    func taskCannotBeCreatedWithoutAVisionInProgress() {
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

    @Test("管理者はプレイヤーが起案したタスクを採用して、未完了のタスクに加えられる")
    func managerCanAdoptPlayerProposedTask() throws {
        // Given
        let (active, _) = try PartnershipState().activeVision()
        let (proposed, taskID) = try active.creatingTask(title: "起案", by: .player)

        // When
        let state = try proposed.adoptingTask(taskID, by: .manager)

        // Then
        #expect(state.status(of: taskID) == .todo)
    }

    @Test("採用を待つ間に期限が過ぎたタスクは、採用できない")
    func taskWhoseDeadlinePassedCannotBeAdopted() throws {
        // Given
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let (active, _) = try PartnershipState().activeVision()
        let (proposed, taskID) = try active.creatingTask(
            title: "起案", deadline: deadline, by: .player, now: deadline.addingTimeInterval(-60)
        )

        // When / Then
        #expect(throws: DomainError.pastDeadline) {
            try proposed.adoptingTask(taskID, by: .manager, now: deadline)
        }
    }

    @Test("管理者は完了報告を差し戻して、未完了に戻せる（やり直しの指示）")
    func managerCanSendACompletionReportBack() throws {
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

    @Test("完了報告されていないタスクは承認できない")
    func taskCannotBeApprovedBeforeItIsReported() throws {
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

    @Test("タスクの期限は、今より後でなければ決められない")
    func taskCannotBeCreatedWithPastDeadline() throws {
        // Given
        let (state, _) = try PartnershipState().activeVision()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

        // When / Then
        #expect(throws: DomainError.pastDeadline) {
            try state.creatingTask(title: "走る", deadline: now.addingTimeInterval(-60), by: .manager, now: now)
        }
    }

    @Test("タスクの詳細は任意で、空白だけなら書かなかったものとして持つ")
    func blankTaskDetailIsKeptAsUnwritten() throws {
        // Given
        let (state, _) = try PartnershipState().activeVision()

        // When
        let (created, taskID) = try state.creatingTask(title: "走る", detail: " \n", by: .manager)

        // Then
        #expect(created.tasks.first { $0.id == taskID }?.detail == nil)
    }

    @Test("タスクの詳細は、前後の空白や改行を落として持つ")
    func taskDetailIsTrimmed() throws {
        // Given
        let (state, _) = try PartnershipState().activeVision()

        // When
        let (created, taskID) = try state.creatingTask(title: "走る", detail: "\n朝に5km\n", by: .manager)

        // Then
        #expect(created.tasks.first { $0.id == taskID }?.detail == "朝に5km")
    }
}
