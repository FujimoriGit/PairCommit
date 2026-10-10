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

    @Test("ビジョンの起案は挑む人だけができる（目的の発生源は挑む人）")
    func onlyPlayerCanDraftVision() {
        // Given
        let state = PartnershipState()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .manager)
        }
    }

    @Test("差し戻された起案は、挑む人が中身を書き直して出し直せる（起案の主導権は挑む人）")
    func playerCanRewriteAVisionThatWasSentBack() throws {
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
            by: .player,
            now: deadline.addingTimeInterval(-24 * 60 * 60)
        )

        // Then
        let vision = try #require(state.visions.first)
        #expect(vision.statement == "半年で5kg痩せる")
        #expect(vision.doneCriteria == "体重計で65kgを切る")
        #expect(vision.deadline == deadline)
        #expect(vision.why == "健康診断で引っかかった")
        #expect(vision.status == .draft)
    }

    @Test(
        "ビジョンの一文と達成基準は、空白だけでは起案できない",
        arguments: [
            Vision.Content(statement: "  ", doneCriteria: "c", deadline: nil, why: nil),
            Vision.Content(statement: "s", doneCriteria: "\n", deadline: nil, why: nil),
        ]
    )
    func visionCannotBeDraftedWithBlankText(content: Vision.Content) {
        // Given
        let state = PartnershipState()

        // When / Then
        #expect(throws: DomainError.blankText) {
            try state.draftingVision(content, by: .player)
        }
    }

    @Test("書き直しでも、ビジョンの一文と達成基準を空白だけにはできない")
    func visionCannotBeRewrittenWithBlankText() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player
        )

        // When / Then
        #expect(throws: DomainError.blankText) {
            try state.revisingVision(visionID, to: .init(statement: " ", doneCriteria: "c", deadline: nil, why: nil), by: .player)
        }
    }

    @Test("ビジョンの期限は、今より後でなければ起案できない")
    func visionCannotBeDraftedWithPastDeadline() {
        // Given
        let state = PartnershipState()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

        // When / Then
        #expect(throws: DomainError.pastDeadline) {
            try state.draftingVision(
                .init(statement: "s", doneCriteria: "c", deadline: now.addingTimeInterval(-60), why: nil), by: .player, now: now
            )
        }
    }

    @Test("期限が過ぎた起案は、書き直さずに出し直せない")
    func visionWhoseDeadlinePassedCannotBeProposed() throws {
        // Given
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: deadline, why: nil),
            by: .player,
            now: deadline.addingTimeInterval(-60)
        )

        // When / Then
        #expect(throws: DomainError.pastDeadline) {
            try state.proposingVision(visionID, by: .player, now: deadline)
        }
    }

    @Test("書き直しでも、ビジョンの期限を過去にはできない")
    func visionCannotBeRewrittenWithPastDeadline() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player
        )
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

        // When / Then
        #expect(throws: DomainError.pastDeadline) {
            try state.revisingVision(
                visionID,
                to: .init(statement: "s", doneCriteria: "c", deadline: now.addingTimeInterval(-60), why: nil),
                by: .player,
                now: now
            )
        }
    }

    @Test("ビジョンの一文・達成基準・動機は、前後の空白や改行を落として持つ")
    func surroundingWhitespaceIsTrimmed() throws {
        // Given
        let state = PartnershipState()

        // When
        let (drafted, _) = try state.draftingVision(
            .init(statement: "\n\nやる\n", doneCriteria: " c ", deadline: nil, why: "　w\n"), by: .player
        )

        // Then
        let vision = try #require(drafted.visions.first)
        #expect(vision.statement == "やる")
        #expect(vision.doneCriteria == "c")
        #expect(vision.why == "w")
    }

    @Test("空白だけの動機で起案すると、動機は書かなかったものとして扱う（動機は推奨で必須ではない）")
    func blankWhyIsTreatedAsUnwritten() throws {
        // Given
        let state = PartnershipState()

        // When
        let (drafted, _) = try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: " \n"), by: .player)

        // Then
        #expect(drafted.visions.first?.why == nil)
    }

    @Test("書き直して動機を空白だけにすると、動機は書かなかったものとして扱う")
    func rewritingTheWhyToBlankLeavesItUnwritten() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: nil, why: "w"), by: .player
        )

        // When
        let rewritten = try state.revisingVision(
            visionID, to: .init(statement: "s", doneCriteria: "c", deadline: nil, why: "　"), by: .player
        )

        // Then
        #expect(rewritten.visions.first?.why == nil)
    }

    @Test("ビジョンを書き直せるのは挑む人だけ（目的は見届ける人が握らない）")
    func onlyPlayerCanRewriteVision() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player
        )

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.revisingVision(visionID, to: .init(statement: "s2", doneCriteria: "c2", deadline: nil, why: nil), by: .manager)
        }
    }

    @Test("提出したあとのビジョンは書き直せない（見届ける人が見ている中身が変わらない）")
    func submittedVisionCannotBeRewritten() throws {
        // Given
        let (state, visionID) = try PartnershipState().proposedVision()

        // When / Then
        #expect(throws: DomainError.invalidVisionTransition(from: .proposed)) {
            try state.revisingVision(visionID, to: .init(statement: "s2", doneCriteria: "c2", deadline: nil, why: nil), by: .player)
        }
    }

    @Test("起案中のビジョンは挑む人が取り下げられ、記録にも残らない")
    func playerCanWithdrawAVisionNotYetSubmitted() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player
        )

        // When
        let discarded = try state.discardingVision(visionID, by: .player)

        // Then
        #expect(discarded.visions.isEmpty)
    }

    @Test("ビジョンを取り下げられるのは挑む人だけ（見届ける人は起案を消せない）")
    func onlyPlayerCanWithdrawVision() throws {
        // Given
        let (state, visionID) = try PartnershipState().draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player
        )

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.discardingVision(visionID, by: .manager)
        }
    }

    @Test("提出したあとのビジョンは取り下げられない（承認するかを決めるのは見届ける人の番）")
    func submittedVisionCannotBeWithdrawn() throws {
        // Given
        let (state, visionID) = try PartnershipState().proposedVision()

        // When / Then
        #expect(throws: DomainError.invalidVisionTransition(from: .proposed)) {
            try state.discardingVision(visionID, by: .player)
        }
    }

    @Test("進行中のビジョンは取り下げられない（閉じるのは見届ける人の達成判断）")
    func visionInProgressCannotBeWithdrawn() throws {
        // Given
        let (state, visionID) = try PartnershipState().activeVision()

        // When / Then
        #expect(throws: DomainError.invalidVisionTransition(from: .active)) {
            try state.discardingVision(visionID, by: .player)
        }
    }
}
