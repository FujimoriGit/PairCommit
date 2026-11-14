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
        let (active, _) = try PartnershipState().activeVision()

        let (state, taskID) = try active.creatingTask(title: "見届ける人が追加", by: .manager)

        #expect(state.status(of: taskID) == .todo)
    }

    @Test("挑む人が起案したタスクは、見届ける人が採用するまで採用待ちになる")
    func taskSuggestedByThePlayerAwaitsAdoption() throws {
        let (active, _) = try PartnershipState().activeVision()

        let (state, taskID) = try active.creatingTask(title: "挑む人が起案", by: .player)

        #expect(state.status(of: taskID) == .proposed)
    }

    @Test("タスクは進行中のビジョンの下にしか作れない")
    func taskCannotBeCreatedWithoutAVisionInProgress() {
        let state = PartnershipState()

        #expect(throws: TaskCreationError.noActiveVision) {
            try state.creatingTask(title: "孤立タスク", by: .manager)
        }
    }

    @Test("挑む人が完了を報告しただけでは、タスクは完了にならず承認待ちになる")
    func reportedTaskAwaitsApprovalInsteadOfCompleting() throws {
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        let reported = try state.reportingTask(taskID, by: .player)

        #expect(reported.status(of: taskID) == .reported)
    }

    @Test("完了の報告を見届ける人が承認すると、タスクは完了になる")
    func taskCompletesOnceTheManagerApprovesTheReport() throws {
        let (created, taskID) = try PartnershipState().activeVisionWithTask()
        let reported = try created.reportingTask(taskID, by: .player)

        let state = try reported.approvingTask(taskID, by: .manager)

        #expect(state.status(of: taskID) == .approved)
    }

    @Test("完了を報告できるのは挑む人だけ")
    func onlyPlayerCanReportCompletion() throws {
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        #expect(throws: TaskReportError.notPlayer) {
            try state.reportingTask(taskID, by: .manager)
        }
    }

    @Test("完了の報告を承認できるのは見届ける人だけ")
    func onlyManagerCanApproveCompletion() throws {
        let (created, taskID) = try PartnershipState().activeVisionWithTask()
        let state = try created.reportingTask(taskID, by: .player)

        #expect(throws: TaskApprovalError.notManager) {
            try state.approvingTask(taskID, by: .player)
        }
    }

    @Test("見届ける人は、挑む人が起案したタスクを採用して、未完了のタスクにできる")
    func managerCanAdoptATaskThePlayerSuggested() throws {
        let (active, _) = try PartnershipState().activeVision()
        let (suggested, taskID) = try active.creatingTask(title: "起案", by: .player)

        let state = try suggested.adoptingTask(taskID, by: .manager)

        #expect(state.status(of: taskID) == .todo)
    }

    @Test("採用を待つ間に期限が過ぎたタスクは、採用できない")
    func taskWhoseDeadlinePassedCannotBeAdopted() throws {
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let (active, _) = try PartnershipState().activeVision()
        let (proposed, taskID) = try active.creatingTask(
            title: "起案", deadline: deadline, by: .player, now: deadline.addingTimeInterval(-60)
        )

        #expect(throws: TaskAdoptionError.pastDeadline) {
            try proposed.adoptingTask(taskID, by: .manager, now: deadline)
        }
    }

    @Test("見届ける人は完了の報告を差し戻して、タスクを未完了に戻せる（やり直しの指示）")
    func managerCanSendACompletionReportBack() throws {
        let (created, taskID) = try PartnershipState().activeVisionWithTask()
        let reported = try created.reportingTask(taskID, by: .player)

        let state = try reported.returningTask(taskID, feedback: "やり直し", by: .manager)

        #expect(state.status(of: taskID) == .todo)
    }

    @Test("見届ける人は、未完了のタスクを取り消せる")
    func managerCanCancelAnIncompleteTask() throws {
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        let cancelled = try state.cancellingTask(taskID, by: .manager)

        #expect(cancelled.status(of: taskID) == .cancelled)
    }

    @Test("見届ける人が取り消したタスクを戻すと、取り消す前の状態に戻る", arguments: [
        TaskItem.Status.proposed, .todo, .reported
    ])
    func cancelledTaskReturnsToItsStatusBeforeCancellation(_ before: TaskItem.Status) throws {
        let (progressed, taskID) = try PartnershipState().activeVisionWithTask(in: before)
        let cancelled = try progressed.cancellingTask(taskID, by: .manager)

        let state = try cancelled.restoringTask(taskID, by: .manager)

        #expect(state.status(of: taskID) == before)
    }

    @Test("取り消したタスクを戻せるのは見届ける人だけ")
    func onlyManagerCanRestoreACancelledTask() throws {
        let (created, taskID) = try PartnershipState().activeVisionWithTask()
        let state = try created.cancellingTask(taskID, by: .manager)

        #expect(throws: TaskRestorationError.notManager) {
            try state.restoringTask(taskID, by: .player)
        }
    }

    @Test("ビジョンを閉じたあとは、取り消したタスクを戻せない")
    func cancelledTaskCannotBeRestoredAfterTheVisionIsClosed() throws {
        let (active, visionID) = try PartnershipState().activeVision()
        let (created, taskID) = try active.creatingTask(title: "t", by: .manager)
        let state = try created
            .cancellingTask(taskID, by: .manager)
            .closingVision(visionID, as: .abandoned, by: .manager)

        #expect(throws: TaskRestorationError.notRestorable) {
            try state.restoringTask(taskID, by: .manager)
        }
    }

    @Test("取り消す前が完了だったことになっているタスクは、戻せない")
    func cancelledTaskCannotBeRestoredAsCompleted() throws {
        let (active, visionID) = try PartnershipState().activeVision()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let task = TaskItem(
            id: UUID(),
            visionID: visionID,
            title: "t",
            detail: nil,
            status: .cancelled,
            createdBy: .manager,
            reaction: nil,
            deadline: nil,
            createdAt: now,
            statusChangedAt: now,
            cancelledFrom: .approved
        )
        let state = PartnershipState(pairing: active.pairing, visions: active.visions, tasks: [task])

        #expect(throws: TaskRestorationError.notRestorable) {
            try state.restoringTask(task.id, by: .manager)
        }
    }

    @Test("取り消していないタスクは戻せない")
    func taskThatIsNotCancelledCannotBeRestored() throws {
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        #expect(throws: TaskRestorationError.notRestorable) {
            try state.restoringTask(taskID, by: .manager)
        }
    }

    @Test("完了したタスクは、見届ける人でも取り消せない")
    func completedTaskCannotBeCancelled() throws {
        let (created, taskID) = try PartnershipState().activeVisionWithTask()
        let state = try created
            .reportingTask(taskID, by: .player)
            .approvingTask(taskID, by: .manager)

        #expect(throws: TaskCancellationError.alreadyClosed) {
            try state.cancellingTask(taskID, by: .manager)
        }
    }

    @Test("完了を報告されていないタスクは承認できない")
    func taskCannotBeApprovedBeforeItIsReported() throws {
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        #expect(throws: TaskApprovalError.notReported) {
            try state.approvingTask(taskID, by: .manager)
        }
    }

    @Test("タスクの名前は、空白だけでは作れない")
    func taskCannotBeCreatedWithBlankTitle() throws {
        let (state, _) = try PartnershipState().activeVision()

        #expect(throws: TaskCreationError.blankTitle) {
            try state.creatingTask(title: "　", by: .manager)
        }
    }

    @Test("タスクの期限は、今より後でなければ決められない")
    func taskCannotBeCreatedWithPastDeadline() throws {
        let (state, _) = try PartnershipState().activeVision()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

        #expect(throws: TaskCreationError.pastDeadline) {
            try state.creatingTask(title: "走る", deadline: now.addingTimeInterval(-60), by: .manager, now: now)
        }
    }

    @Test("タスクの詳細は任意で、空白だけなら書かなかったものとして持つ")
    func blankTaskDetailIsKeptAsUnwritten() throws {
        let (state, _) = try PartnershipState().activeVision()

        let (created, taskID) = try state.creatingTask(title: "走る", detail: " \n", by: .manager)

        #expect(created.tasks.first { $0.id == taskID }?.detail == nil)
    }

    @Test("タスクの名前と詳細は、前後の空白や改行を落として持つ")
    func taskTitleAndDetailAreTrimmed() throws {
        let (state, _) = try PartnershipState().activeVision()

        let (created, taskID) = try state.creatingTask(title: " 走る\n", detail: "\n朝に5km\n", by: .manager)

        let task = try #require(created.tasks.first { $0.id == taskID })
        #expect(task.title == "走る")
        #expect(task.detail == "朝に5km")
    }
}
