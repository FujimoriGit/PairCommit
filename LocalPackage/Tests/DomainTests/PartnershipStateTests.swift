//
//  PartnershipStateTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Domain
import Foundation
import Testing

struct PartnershipStateTests {

    // MARK: - ペアリング

    @Test("ペアは一度しか確立できない（ロール固定・スワップなしの前提）")
    func pairingCanBeEstablishedOnlyOnce() throws {
        // Given
        let state = PartnershipState()

        // When
        let paired = try state.establishingPairing(ownerRole: .manager)

        // Then
        #expect(paired.pairing?.ownerRole == .manager)
        #expect(throws: DomainError.alreadyPaired) {
            try paired.establishingPairing(ownerRole: .player)
        }
    }

    // MARK: - Vision ライフサイクル

    @Test("プレイヤーが起案し、管理者が承認するとビジョンは active になる")
    func visionBecomesActiveWhenManagerApprovesPlayersProposal() throws {
        // Given
        let (drafted, visionID) = try PartnershipState().draftingVision(
            statement: "半年で10kg痩せる", doneCriteria: "健康診断オールA", by: .player
        )

        // When
        let state = try drafted
            .proposingVision(visionID, by: .player)
            .approvingVision(visionID, by: .manager)

        // Then
        #expect(state.activeVision?.id == visionID)
    }

    @Test("ビジョンの起案はプレイヤーだけができる（目的の発生源はプレイヤー）")
    func onlyPlayerCanDraftVision() {
        // Given
        let state = PartnershipState()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.draftingVision(statement: "s", doneCriteria: "c", by: .manager)
        }
    }

    @Test("ビジョンの承認は管理者だけができる（執行権限は管理者）")
    func onlyManagerCanApproveVision() throws {
        // Given
        let (state, visionID) = try PartnershipState().proposedVision()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.approvingVision(visionID, by: .player)
        }
    }

    @Test("active なビジョンは高々1個 ── 既に active があるとき2つ目の承認は失敗する")
    func approvingSecondVisionWhileOneIsActiveFails() throws {
        // Given
        let (active, _) = try PartnershipState().activeVision()
        let (state, second) = try active.proposedVision()

        // When / Then
        #expect(throws: DomainError.activeVisionAlreadyExists) {
            try state.approvingVision(second, by: .manager)
        }
    }

    @Test("管理者は承認待ちビジョンを draft に差し戻せる（却下は削除ではない）")
    func managerCanSendProposedVisionBackToDraft() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()

        // When
        let state = try proposed.rejectingVision(visionID, by: .manager)

        // Then
        #expect(state.visions.first?.status == .draft)
    }

    @Test("起案中（draft）のビジョンをいきなり承認はできない（提出を経る）")
    func draftVisionCannotBeApprovedDirectly() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            statement: "s", doneCriteria: "c", by: .player
        )

        // When / Then
        #expect(throws: DomainError.invalidVisionTransition(from: .draft)) {
            try state.approvingVision(visionID, by: .manager)
        }
    }

    @Test("ビジョンを閉じると、配下の未完了タスクは巻き込みで cancelled になり、完了済みは残る")
    func closingVisionCancelsItsOpenTasksButKeepsApprovedOnes() throws {
        // Given
        let (active, visionID) = try PartnershipState().activeVision()
        let (withTodo, todoTask) = try active.creatingTask(title: "todoのまま", by: .manager)
        let (withReported, reportedTask) = try withTodo.creatingTask(title: "報告済み", by: .manager)
        let (withProposed, proposedTask) = try withReported
            .reportingTask(reportedTask, by: .player)
            .creatingTask(title: "プレイヤー起案", by: .player)
        let (withApproved, approvedTask) = try withProposed.creatingTask(title: "承認済み", by: .manager)
        let ready = try withApproved
            .reportingTask(approvedTask, by: .player)
            .approvingTask(approvedTask, by: .manager)

        // When
        let state = try ready.closingVision(visionID, as: .achieved, by: .manager)

        // Then
        #expect(state.visions.first?.status == .achieved)
        #expect(state.status(of: todoTask) == .cancelled)
        #expect(state.status(of: reportedTask) == .cancelled)
        #expect(state.status(of: proposedTask) == .cancelled)
        #expect(state.status(of: approvedTask) == .approved)
        #expect(state.activeVision == nil)
    }

    @Test("達成・中止の判断は管理者だけができる（プレイヤーはビジョンを閉じられない）")
    func onlyManagerCanCloseVision() throws {
        // Given
        let (state, visionID) = try PartnershipState().activeVision()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.closingVision(visionID, as: .abandoned, by: .player)
        }
    }

    @Test("前のビジョンを閉じれば、次のビジョンを承認できる（焦点は常に1つ）")
    func nextVisionCanBeApprovedAfterClosingCurrentOne() throws {
        // Given
        let (active, first) = try PartnershipState().activeVision()
        let (proposed, second) = try active
            .closingVision(first, as: .abandoned, by: .manager)
            .proposedVision()

        // When
        let state = try proposed.approvingVision(second, by: .manager)

        // Then
        #expect(state.activeVision?.id == second)
    }

    @Test("履歴に残るのは閉じたビジョンだけで、新しく起案したものから並ぶ")
    func closedVisionsAreListedNewestFirst() throws {
        // Given
        let older = try PartnershipState().closedVision(
            statement: "古い方", as: .abandoned, now: Date(timeIntervalSince1970: 0)
        )
        let newer = try older.closedVision(
            statement: "新しい方", as: .achieved, now: Date(timeIntervalSince1970: 86_400)
        )

        // When
        let (state, _) = try newer.activeVision()

        // Then
        #expect(state.closedVisions.map(\.statement) == ["新しい方", "古い方"])
    }

    // MARK: - タスクライフサイクル

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

    // MARK: - 感情リアクション

    @Test("プレイヤーは感情を上書きで表明でき、取り下げもできる（ステートでありストリームではない）")
    func playerCanOverwriteAndClearReaction() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        let uneasy = try state.settingReaction(.uneasy, on: taskID, by: .player)
        #expect(uneasy.tasks.first?.reaction == .uneasy)

        let happy = try uneasy.settingReaction(.happy, on: taskID, by: .player)
        #expect(happy.tasks.first?.reaction == .happy)

        let cleared = try happy.settingReaction(nil, on: taskID, by: .player)
        #expect(cleared.tasks.first?.reaction == nil)
    }

    @Test("感情の表明はプレイヤーだけができる（唯一の主体性は感情チャンネル）")
    func onlyPlayerCanExpressReaction() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.settingReaction(.angry, on: taskID, by: .manager)
        }
    }

    // MARK: - 同期での往復

    @Test("状態は JSON に載せて往復しても失われない（同期はこの形で運ぶ）")
    func stateSurvivesJSONRoundTrip() throws {
        // Given
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let (paired, visionID) = try PartnershipState()
            .establishingPairing(ownerRole: .manager)
            .draftingVision(statement: "半年で10kg痩せる", doneCriteria: "健康診断オールA", deadline: deadline, by: .player)
        let (active, taskID) = try paired
            .proposingVision(visionID, by: .player)
            .approvingVision(visionID, by: .manager)
            .creatingTask(title: "毎朝30分歩く", deadline: deadline, by: .manager)
        let state = try active.settingReaction(.angry, on: taskID, by: .player)

        // When
        let restored = try JSONDecoder().decode(
            PartnershipState.self, from: JSONEncoder().encode(state)
        )

        // Then
        #expect(restored == state)
    }
}

// MARK: - テストヘルパー

private extension PartnershipState {
    func proposedVision() throws -> (state: PartnershipState, visionID: Vision.ID) {
        let (drafted, visionID) = try draftingVision(
            statement: "statement", doneCriteria: "criteria", by: .player
        )
        return (try drafted.proposingVision(visionID, by: .player), visionID)
    }

    func activeVision() throws -> (state: PartnershipState, visionID: Vision.ID) {
        let (proposed, visionID) = try proposedVision()
        return (try proposed.approvingVision(visionID, by: .manager), visionID)
    }

    func activeVisionWithTask(title: String = "t") throws -> (state: PartnershipState, taskID: TaskItem.ID) {
        let (active, _) = try activeVision()
        return try active.creatingTask(title: title, by: .manager)
    }

    func closedVision(statement: String, as outcome: Vision.Outcome, now: Date) throws -> PartnershipState {
        let (drafted, visionID) = try draftingVision(
            statement: statement, doneCriteria: "criteria", by: .player, now: now
        )
        return try drafted
            .proposingVision(visionID, by: .player)
            .approvingVision(visionID, by: .manager)
            .closingVision(visionID, as: outcome, by: .manager)
    }

    func status(of taskID: TaskItem.ID) -> TaskItem.Status? {
        tasks.first { $0.id == taskID }?.status
    }
}
