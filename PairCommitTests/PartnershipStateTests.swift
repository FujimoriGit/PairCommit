//
//  PartnershipStateTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Domain
import Foundation
import Testing

/// ドメインの不変条件・ロールの非対称性・状態遷移を、公開API（集約ルートの操作）だけで検証する。
/// 実装詳細ではなく「ビジネスルールとして観測可能な振る舞い」をテストする。
struct PartnershipStateTests {

    // MARK: - ペアリング

    @Test("ペアは一度しか確立できない（ロール固定・スワップなしの前提）")
    func pairingCanBeEstablishedOnlyOnce() throws {
        // Given
        var state = PartnershipState()

        // When
        try state.establishPairing(ownerRole: .manager)

        // Then
        #expect(state.pairing?.ownerRole == .manager)
        #expect(throws: DomainError.alreadyPaired) {
            try state.establishPairing(ownerRole: .player)
        }
    }

    // MARK: - Vision ライフサイクル

    @Test("プレイヤーが起案し、管理者が承認するとビジョンは active になる")
    func visionBecomesActiveWhenManagerApprovesPlayersProposal() throws {
        // Given
        var state = PartnershipState()
        let visionID = try state.draftVision(
            statement: "半年で10kg痩せる", doneCriteria: "健康診断オールA", by: .player
        )

        // When
        try state.proposeVision(visionID, by: .player)
        try state.approveVision(visionID, by: .manager)

        // Then
        #expect(state.activeVision?.id == visionID)
    }

    @Test("ビジョンの起案はプレイヤーだけができる（目的の発生源はプレイヤー）")
    func onlyPlayerCanDraftVision() {
        // Given
        var state = PartnershipState()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.draftVision(statement: "s", doneCriteria: "c", by: .manager)
        }
    }

    @Test("ビジョンの承認は管理者だけができる（執行権限は管理者）")
    func onlyManagerCanApproveVision() throws {
        // Given
        var state = PartnershipState()
        let visionID = try state.proposedVision()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.approveVision(visionID, by: .player)
        }
    }

    @Test("active なビジョンは高々1個 ── 既に active があるとき2つ目の承認は失敗する")
    func approvingSecondVisionWhileOneIsActiveFails() throws {
        // Given
        var state = PartnershipState()
        try state.makeActiveVision()
        let second = try state.proposedVision()

        // When / Then
        #expect(throws: DomainError.activeVisionAlreadyExists) {
            try state.approveVision(second, by: .manager)
        }
    }

    @Test("管理者は承認待ちビジョンを draft に差し戻せる（却下は削除ではない）")
    func managerCanSendProposedVisionBackToDraft() throws {
        // Given
        var state = PartnershipState()
        let visionID = try state.proposedVision()

        // When
        try state.rejectVision(visionID, by: .manager)

        // Then
        #expect(state.visions.first?.status == .draft)
    }

    @Test("起案中（draft）のビジョンをいきなり承認はできない（提出を経る）")
    func draftVisionCannotBeApprovedDirectly() throws {
        // Given
        var state = PartnershipState()
        let visionID = try state.draftVision(statement: "s", doneCriteria: "c", by: .player)

        // When / Then
        #expect(throws: DomainError.invalidVisionTransition(from: .draft)) {
            try state.approveVision(visionID, by: .manager)
        }
    }

    @Test("ビジョンを閉じると、配下の未完了タスクは巻き込みで cancelled になり、完了済みは残る")
    func closingVisionCancelsItsOpenTasksButKeepsApprovedOnes() throws {
        // Given
        var state = PartnershipState()
        let visionID = try state.makeActiveVision()
        let todoTask = try state.createTask(title: "todoのまま", by: .manager)
        let reportedTask = try state.createTask(title: "報告済み", by: .manager)
        try state.reportTask(reportedTask, by: .player)
        let proposedTask = try state.createTask(title: "プレイヤー起案", by: .player)
        let approvedTask = try state.createTask(title: "承認済み", by: .manager)
        try state.reportTask(approvedTask, by: .player)
        try state.approveTask(approvedTask, by: .manager)

        // When
        try state.closeVision(visionID, as: .achieved, by: .manager)

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
        var state = PartnershipState()
        let visionID = try state.makeActiveVision()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.closeVision(visionID, as: .abandoned, by: .player)
        }
    }

    @Test("前のビジョンを閉じれば、次のビジョンを承認できる（焦点は常に1つ）")
    func nextVisionCanBeApprovedAfterClosingCurrentOne() throws {
        // Given
        var state = PartnershipState()
        let first = try state.makeActiveVision()
        try state.closeVision(first, as: .abandoned, by: .manager)
        let second = try state.proposedVision()

        // When
        try state.approveVision(second, by: .manager)

        // Then
        #expect(state.activeVision?.id == second)
    }

    // MARK: - タスクライフサイクル

    @Test("管理者が作るタスクは todo から、プレイヤー起案は proposed（採用待ち）から始まる")
    func taskStartsAsTodoForManagerAndProposedForPlayer() throws {
        // Given
        var state = PartnershipState()
        try state.makeActiveVision()

        // When
        let byManager = try state.createTask(title: "管理者生成", by: .manager)
        let byPlayer = try state.createTask(title: "プレイヤー起案", by: .player)

        // Then
        #expect(state.status(of: byManager) == .todo)
        #expect(state.status(of: byPlayer) == .proposed)
    }

    @Test("タスクは active なビジョンの下にしか作れない（孤立タスクは存在しない）")
    func taskCannotBeCreatedWithoutActiveVision() {
        // Given
        var state = PartnershipState()

        // When / Then
        #expect(throws: DomainError.noActiveVision) {
            try state.createTask(title: "孤立タスク", by: .manager)
        }
    }

    @Test("プレイヤーが完了報告し、管理者が承認して初めてタスクは完了になる")
    func taskCompletesOnlyThroughReportThenApproval() throws {
        // Given
        var state = PartnershipState()
        try state.makeActiveVision()
        let taskID = try state.createTask(title: "t", by: .manager)

        // When / Then
        try state.reportTask(taskID, by: .player)
        #expect(state.status(of: taskID) == .reported)

        try state.approveTask(taskID, by: .manager)
        #expect(state.status(of: taskID) == .approved)
    }

    @Test("完了報告はプレイヤーだけ、完了承認は管理者だけができる（役割の非対称性）")
    func reportingIsPlayersJobAndApprovalIsManagersJob() throws {
        // Given
        var state = PartnershipState()
        try state.makeActiveVision()
        let taskID = try state.createTask(title: "t", by: .manager)

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.reportTask(taskID, by: .manager)
        }
        try state.reportTask(taskID, by: .player)
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.approveTask(taskID, by: .player)
        }
    }

    @Test("管理者はプレイヤー起案のタスクを採用して todo にできる")
    func managerCanAdoptPlayerProposedTask() throws {
        // Given
        var state = PartnershipState()
        try state.makeActiveVision()
        let taskID = try state.createTask(title: "起案", by: .player)

        // When
        try state.adoptTask(taskID, by: .manager)

        // Then
        #expect(state.status(of: taskID) == .todo)
    }

    @Test("管理者は完了報告を差し戻して todo に戻せる（やり直しの指示）")
    func managerCanReturnReportedTaskToTodo() throws {
        // Given
        var state = PartnershipState()
        try state.makeActiveVision()
        let taskID = try state.createTask(title: "t", by: .manager)
        try state.reportTask(taskID, by: .player)

        // When
        try state.returnTask(taskID, by: .manager)

        // Then
        #expect(state.status(of: taskID) == .todo)
    }

    @Test("管理者は未完了タスクを取り下げられるが、承認済み（完了）は取り消せない")
    func managerCanCancelOpenTasksButNotApprovedOnes() throws {
        // Given
        var state = PartnershipState()
        try state.makeActiveVision()
        let openTask = try state.createTask(title: "未完了", by: .manager)
        let doneTask = try state.createTask(title: "完了", by: .manager)
        try state.reportTask(doneTask, by: .player)
        try state.approveTask(doneTask, by: .manager)

        // When
        try state.cancelTask(openTask, by: .manager)

        // Then
        #expect(state.status(of: openTask) == .cancelled)
        #expect(throws: DomainError.invalidTaskTransition(from: .approved)) {
            try state.cancelTask(doneTask, by: .manager)
        }
    }

    @Test("完了報告を経ないタスクは承認できない（todo からの直接承認は不可）")
    func todoTaskCannotBeApprovedWithoutReport() throws {
        // Given
        var state = PartnershipState()
        try state.makeActiveVision()
        let taskID = try state.createTask(title: "t", by: .manager)

        // When / Then
        #expect(throws: DomainError.invalidTaskTransition(from: .todo)) {
            try state.approveTask(taskID, by: .manager)
        }
    }

    // MARK: - 感情リアクション

    @Test("プレイヤーは感情を上書きで表明でき、取り下げもできる（ステートでありストリームではない）")
    func playerCanOverwriteAndClearReaction() throws {
        // Given
        var state = PartnershipState()
        try state.makeActiveVision()
        let taskID = try state.createTask(title: "t", by: .manager)

        // When / Then
        try state.setReaction(.uneasy, on: taskID, by: .player)
        #expect(state.tasks.first?.reaction == .uneasy)

        try state.setReaction(.happy, on: taskID, by: .player)
        #expect(state.tasks.first?.reaction == .happy)

        try state.setReaction(nil, on: taskID, by: .player)
        #expect(state.tasks.first?.reaction == nil)
    }

    @Test("感情の表明はプレイヤーだけができる（唯一の主体性は感情チャンネル）")
    func onlyPlayerCanExpressReaction() throws {
        // Given
        var state = PartnershipState()
        try state.makeActiveVision()
        let taskID = try state.createTask(title: "t", by: .manager)

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.setReaction(.angry, on: taskID, by: .manager)
        }
    }
}

// MARK: - テストヘルパー

private extension PartnershipState {
    /// draft → proposed まで進めた Vision を作る。
    mutating func proposedVision() throws -> Vision.ID {
        let visionID = try draftVision(statement: "statement", doneCriteria: "criteria", by: .player)
        try proposeVision(visionID, by: .player)
        return visionID
    }

    /// active な Vision を1つ用意する。
    @discardableResult
    mutating func makeActiveVision() throws -> Vision.ID {
        let visionID = try proposedVision()
        try approveVision(visionID, by: .manager)
        return visionID
    }

    func status(of taskID: TaskItem.ID) -> TaskItem.Status? {
        tasks.first { $0.id == taskID }?.status
    }
}
