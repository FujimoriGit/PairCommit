//
//  VisionDraftingTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/26
//

import Domain
import Foundation
import Testing

struct VisionDraftingTests {

    @Test("ビジョンの起案はプレイヤーだけができる（目的の発生源はプレイヤー）")
    func onlyPlayerCanDraftVision() {
        // Given
        let state = PartnershipState()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.draftingVision(.init(statement: "s", doneCriteria: "c"), by: .manager)
        }
    }

    @Test("差し戻された起案は、プレイヤーが中身を書き直して出し直せる（起案の主導権はプレイヤー）")
    func playerCanReviseVisionSentBackToDraft() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()
        let returned = try proposed.rejectingVision(visionID, by: .manager)
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)

        // When
        let state = try returned.revisingVision(
            visionID,
            to: .init(
                statement: "半年で5kg痩せる",
                doneCriteria: "体重計で65kgを切る",
                deadline: deadline,
                why: "健康診断で引っかかった"
            ),
            by: .player
        )

        // Then
        let vision = try #require(state.visions.first)
        #expect(vision.statement == "半年で5kg痩せる")
        #expect(vision.doneCriteria == "体重計で65kgを切る")
        #expect(vision.deadline == deadline)
        #expect(vision.why == "健康診断で引っかかった")
        #expect(vision.status == .draft)
    }

    @Test("ビジョンの一文と達成基準は、空白だけでは起案できない")
    func visionCannotBeDraftedWithBlankText() {
        // Given
        let state = PartnershipState()

        // When / Then
        #expect(throws: DomainError.blankText) {
            try state.draftingVision(.init(statement: "  ", doneCriteria: "c"), by: .player)
        }
        #expect(throws: DomainError.blankText) {
            try state.draftingVision(.init(statement: "s", doneCriteria: "\n"), by: .player)
        }
    }

    @Test("書き直しでも、ビジョンの一文と達成基準を空白だけにはできない")
    func visionCannotBeRevisedToBlankText() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c"), by: .player
        )

        // When / Then
        #expect(throws: DomainError.blankText) {
            try state.revisingVision(visionID, to: .init(statement: " ", doneCriteria: "c"), by: .player)
        }
    }

    @Test("前後の空白や改行は落として持つ")
    func surroundingWhitespaceIsTrimmed() throws {
        // Given
        let (drafted, visionID) = try PartnershipState().draftingVision(
            .init(statement: "\n\nやる\n", doneCriteria: " c ", why: "　w\n"), by: .player
        )
        let active = try drafted
            .proposingVision(visionID, by: .player)
            .approvingVision(visionID, by: .manager)

        // When
        let (state, taskID) = try active.creatingTask(title: " t\n", by: .manager)

        // Then
        let vision = try #require(state.visions.first)
        #expect(vision.statement == "やる")
        #expect(vision.doneCriteria == "c")
        #expect(vision.why == "w")
        #expect(state.tasks.first { $0.id == taskID }?.title == "t")
    }

    @Test("空白だけの動機は、書かなかったものとして扱う（動機は推奨で必須ではない）")
    func blankWhyIsTreatedAsUnwritten() throws {
        // Given
        let state = PartnershipState()

        // When
        let (drafted, visionID) = try state.draftingVision(.init(statement: "s", doneCriteria: "c", why: " \n"), by: .player)
        let revised = try drafted.revisingVision(
            visionID, to: .init(statement: "s", doneCriteria: "c", why: "　"), by: .player
        )

        // Then
        #expect(drafted.visions.first?.why == nil)
        #expect(revised.visions.first?.why == nil)
    }

    @Test("ビジョンを書き直せるのはプレイヤーだけ（目的は管理者が握らない）")
    func onlyPlayerCanReviseVision() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c"), by: .player
        )

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.revisingVision(visionID, to: .init(statement: "s2", doneCriteria: "c2"), by: .manager)
        }
    }

    @Test("提出したあとのビジョンは書き直せない（管理者が見ている中身が変わらない）")
    func proposedVisionCannotBeRevised() throws {
        // Given
        let (state, visionID) = try PartnershipState().proposedVision()

        // When / Then
        #expect(throws: DomainError.invalidVisionTransition(from: .proposed)) {
            try state.revisingVision(visionID, to: .init(statement: "s2", doneCriteria: "c2"), by: .player)
        }
    }

    @Test("起案中のビジョンはプレイヤーが取り下げられ、記録にも残らない")
    func playerCanDiscardDraftVision() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c"), by: .player
        )

        // When
        let discarded = try state.discardingVision(visionID, by: .player)

        // Then
        #expect(discarded.visions.isEmpty)
    }

    @Test("ビジョンを取り下げられるのはプレイヤーだけ（管理者は起案を消せない）")
    func onlyPlayerCanDiscardVision() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c"), by: .player
        )

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.discardingVision(visionID, by: .manager)
        }
    }

    @Test("提出したあとのビジョンは取り下げられない（承認するかを決めるのは管理者の番）")
    func proposedVisionCannotBeDiscarded() throws {
        // Given
        let (state, visionID) = try PartnershipState().proposedVision()

        // When / Then
        #expect(throws: DomainError.invalidVisionTransition(from: .proposed)) {
            try state.discardingVision(visionID, by: .player)
        }
    }

    @Test("進行中のビジョンは取り下げられない（閉じるのは管理者の達成判断）")
    func activeVisionCannotBeDiscarded() throws {
        // Given
        let (state, visionID) = try PartnershipState().activeVision()

        // When / Then
        #expect(throws: DomainError.invalidVisionTransition(from: .active)) {
            try state.discardingVision(visionID, by: .player)
        }
    }
}
