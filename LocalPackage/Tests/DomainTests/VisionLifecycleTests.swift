//
//  VisionLifecycleTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/26
//

import Domain
import Foundation
import Testing

struct VisionLifecycleTests {

    @Test("プレイヤーが起案し、管理者が承認するとビジョンは active になる")
    func visionBecomesActiveWhenManagerApprovesPlayersProposal() throws {
        // Given
        let (drafted, visionID) = try PartnershipState().draftingVision(
            .init(statement: "半年で10kg痩せる", doneCriteria: "健康診断オールA", deadline: nil, why: nil), by: .player
        )

        // When
        let state = try drafted
            .proposingVision(visionID, by: .player)
            .approvingVision(visionID, by: .manager)

        // Then
        #expect(state.activeVision?.id == visionID)
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
            .init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player
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

    @Test("履歴に残るのは閉じたビジョンだけ")
    func historyHoldsOnlyClosedVisions() throws {
        // Given
        let (state, _) = try PartnershipState()
            .closedVision(statement: "閉じた方", as: .achieved, now: Date(timeIntervalSince1970: 0))
            .activeVision()

        // When
        let closed = state.closedVisions

        // Then
        #expect(closed.map(\.vision.statement) == ["閉じた方"])
    }

    @Test("履歴は新しく起案したビジョンから並ぶ")
    func closedVisionsAreListedNewestFirst() throws {
        // Given
        let state = try PartnershipState()
            .closedVision(statement: "古い方", as: .abandoned, now: Date(timeIntervalSince1970: 0))
            .closedVision(statement: "新しい方", as: .achieved, now: Date(timeIntervalSince1970: 86_400))

        // When
        let closed = state.closedVisions

        // Then
        #expect(closed.map(\.vision.statement) == ["新しい方", "古い方"])
    }

    @Test("履歴のビジョンには、閉じたときの結果が付く")
    func closedVisionCarriesItsOutcome() throws {
        // Given
        let state = try PartnershipState()
            .closedVision(statement: "取りやめた方", as: .abandoned, now: Date(timeIntervalSince1970: 0))
            .closedVision(statement: "達成した方", as: .achieved, now: Date(timeIntervalSince1970: 86_400))

        // When
        let closed = state.closedVisions

        // Then
        #expect(closed.map(\.outcome) == [.achieved, .abandoned])
    }
}
