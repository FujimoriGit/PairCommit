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

    @Test("挑む人が提出したビジョンを見届ける人が承認すると、進行中のビジョンになる")
    func visionIsInProgressOnceManagerApprovesIt() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()

        // When
        let state = try proposed.approvingVision(visionID, by: .manager)

        // Then
        #expect(state.activeVision?.id == visionID)
    }

    @Test("挑む人が書いたビジョンを提出すると、書いた中身のまま見届ける人の承認待ちになる")
    func submittedVisionAwaitsManagersApprovalAsWritten() throws {
        // Given
        let content = Vision.Content(statement: "半年で10kg痩せる", doneCriteria: "健康診断オールA", deadline: nil, why: nil)

        // When
        let (state, visionID) = try PartnershipState().submittingVision(content, by: .player)

        // Then
        let vision = try #require(state.visions.first(where: { $0.id == visionID }))
        #expect(vision.statement == "半年で10kg痩せる")
        #expect(vision.status == .proposed)
    }

    @Test("差し戻されたビジョンを挑む人が書き直して提出し直すと、書き直した中身で見届ける人の承認待ちに戻る")
    func resubmittedVisionAwaitsManagersApprovalAsRevised() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()
        let returned = try proposed.rejectingVision(visionID, by: .manager)

        // When
        let state = try returned.resubmittingVision(
            visionID,
            as: .init(statement: "半年で5kg痩せる", doneCriteria: "体重計で65kgを切る", deadline: nil, why: nil),
            by: .player
        )

        // Then
        let vision = try #require(state.visions.first(where: { $0.id == visionID }))
        #expect(vision.statement == "半年で5kg痩せる")
        #expect(vision.status == .proposed)
    }

    @Test("ビジョンを承認できるのは見届ける人だけ")
    func onlyManagerCanApproveVision() throws {
        // Given
        let (state, visionID) = try PartnershipState().proposedVision()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.approvingVision(visionID, by: .player)
        }
    }

    @Test("承認を待つ間に期限が過ぎたビジョンは、承認できない")
    func visionWhoseDeadlinePassedCannotBeApproved() throws {
        // Given
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let before = deadline.addingTimeInterval(-60)
        let (drafted, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: deadline, why: nil), by: .player, now: before
        )
        let state = try drafted.proposingVision(visionID, by: .player, now: before)

        // When / Then
        #expect(throws: DomainError.pastDeadline) {
            try state.approvingVision(visionID, by: .manager, now: deadline)
        }
    }

    @Test("進行中のビジョンは1つだけ ── 進行中のビジョンがあるうちは、次のビジョンを承認できない")
    func secondVisionCannotBeApprovedWhileOneIsInProgress() throws {
        // Given
        let (active, _) = try PartnershipState().activeVision()
        let (state, second) = try active.proposedVision()

        // When / Then
        #expect(throws: DomainError.activeVisionAlreadyExists) {
            try state.approvingVision(second, by: .manager)
        }
    }

    @Test("見届ける人は承認待ちのビジョンを差し戻して、挑む人が書き直せるように戻せる（却下は削除ではない）")
    func managerCanSendASubmittedVisionBack() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()

        // When
        let state = try proposed.rejectingVision(visionID, by: .manager)

        // Then
        #expect(state.visions.first?.status == .draft)
    }

    @Test("提出されていないビジョンは承認できない")
    func visionNotYetSubmittedCannotBeApproved() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player
        )

        // When / Then
        #expect(throws: DomainError.invalidVisionTransition(from: .draft)) {
            try state.approvingVision(visionID, by: .manager)
        }
    }

    @Test("ビジョンを閉じると、そのビジョンの未完了・採用待ち・承認待ちのタスクは取り消しになり、完了したタスクは完了のまま残る")
    func closingAVisionCancelsUnfinishedTasksButKeepsCompletedOnes() throws {
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

    @Test("達成したか取りやめるかを判断してビジョンを閉じられるのは、見届ける人だけ")
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

    @Test("記録に残るのは閉じたビジョンだけ")
    func recordHoldsOnlyClosedVisions() throws {
        // Given
        let (state, _) = try PartnershipState()
            .closedVision(statement: "閉じた方", as: .achieved, now: Date(timeIntervalSince1970: 0))
            .activeVision()

        // When
        let closed = state.closedVisions

        // Then
        #expect(closed.map(\.vision.statement) == ["閉じた方"])
    }

    @Test("記録は新しく起案したビジョンから並ぶ")
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

    @Test("記録のビジョンには、閉じたときの結果（達成・取りやめ）が付く")
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
