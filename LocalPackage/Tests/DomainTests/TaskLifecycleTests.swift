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

    @Test("見届ける人が追加したタスクは、すぐ未完了として並ぶ")
    func taskAddedByTheManagerIsIncompleteAtOnce() throws {
        // Given
        let (active, _) = try PartnershipState().activeVision()

        // When
        let (state, taskID) = try active.creatingTask(title: "見届ける人が追加", by: .manager)

        // Then
        #expect(state.status(of: taskID) == .todo)
    }

    @Test("挑む人が起案したタスクは、見届ける人が採用するまで採用待ちになる")
    func taskSuggestedByThePlayerAwaitsAdoption() throws {
        // Given
        let (active, _) = try PartnershipState().activeVision()

        // When
        let (state, taskID) = try active.creatingTask(title: "挑む人が起案", by: .player)

        // Then
        #expect(state.status(of: taskID) == .proposed)
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

    @Test("挑む人が完了を報告しただけでは、タスクは完了にならず承認待ちになる")
    func reportedTaskAwaitsApprovalInsteadOfCompleting() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When
        let reported = try state.reportingTask(taskID, by: .player)

        // Then
        #expect(reported.status(of: taskID) == .reported)
    }

    @Test("完了の報告を見届ける人が承認すると、タスクは完了になる")
    func taskCompletesOnceTheManagerApprovesTheReport() throws {
        // Given
        let (created, taskID) = try PartnershipState().activeVisionWithTask()
        let reported = try created.reportingTask(taskID, by: .player)

        // When
        let state = try reported.approvingTask(taskID, by: .manager)

        // Then
        #expect(state.status(of: taskID) == .approved)
    }

    @Test("完了を報告できるのは挑む人だけ")
    func onlyPlayerCanReportCompletion() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.reportingTask(taskID, by: .manager)
        }
    }

    @Test("完了の報告を承認できるのは見届ける人だけ")
    func onlyManagerCanApproveCompletion() throws {
        // Given
        let (created, taskID) = try PartnershipState().activeVisionWithTask()
        let state = try created.reportingTask(taskID, by: .player)

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.approvingTask(taskID, by: .player)
        }
    }

    @Test("見届ける人は、挑む人が起案したタスクを採用して、未完了のタスクにできる")
    func managerCanAdoptATaskThePlayerSuggested() throws {
        // Given
        let (active, _) = try PartnershipState().activeVision()
        let (suggested, taskID) = try active.creatingTask(title: "起案", by: .player)

        // When
        let state = try suggested.adoptingTask(taskID, by: .manager)

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

    @Test("見届ける人は完了の報告を差し戻して、タスクを未完了に戻せる（やり直しの指示）")
    func managerCanSendACompletionReportBack() throws {
        // Given
        let (created, taskID) = try PartnershipState().activeVisionWithTask()
        let reported = try created.reportingTask(taskID, by: .player)

        // When
        let state = try reported.returningTask(taskID, by: .manager)

        // Then
        #expect(state.status(of: taskID) == .todo)
    }

    @Test("見届ける人は、未完了のタスクを取り消せる")
    func managerCanCancelAnIncompleteTask() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When
        let cancelled = try state.cancellingTask(taskID, by: .manager)

        // Then
        #expect(cancelled.status(of: taskID) == .cancelled)
    }

    @Test("完了したタスクは、見届ける人でも取り消せない")
    func completedTaskCannotBeCancelled() throws {
        // Given
        let (created, taskID) = try PartnershipState().activeVisionWithTask()
        let state = try created
            .reportingTask(taskID, by: .player)
            .approvingTask(taskID, by: .manager)

        // When / Then
        #expect(throws: DomainError.invalidTaskTransition(from: .approved)) {
            try state.cancellingTask(taskID, by: .manager)
        }
    }

    @Test("完了を報告されていないタスクは承認できない")
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

    @Test("タスクの名前と詳細は、前後の空白や改行を落として持つ")
    func taskTitleAndDetailAreTrimmed() throws {
        // Given
        let (state, _) = try PartnershipState().activeVision()

        // When
        let (created, taskID) = try state.creatingTask(title: " 走る\n", detail: "\n朝に5km\n", by: .manager)

        // Then
        let task = try #require(created.tasks.first { $0.id == taskID })
        #expect(task.title == "走る")
        #expect(task.detail == "朝に5km")
    }
}
