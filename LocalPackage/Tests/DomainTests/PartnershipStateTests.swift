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

    @Test("ペアは一度しか組めない（役割は固定で入れ替えない）")
    func aPairCanBeFormedOnlyOnce() throws {
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

    // MARK: - 感情リアクション

    @Test("プレイヤーはタスクへの感情を付け直すことも、外すこともできる（残るのは最後に付けた感情だけ）")
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

    @Test("保存して読み直しても、ペアの状態は何も失われない")
    func stateSurvivesBeingSavedAndReadBack() throws {
        // Given
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let now = deadline.addingTimeInterval(-24 * 60 * 60)
        let (paired, visionID) = try PartnershipState()
            .establishingPairing(ownerRole: .manager)
            .draftingVision(
                .init(statement: "半年で10kg痩せる", doneCriteria: "健康診断オールA", deadline: deadline, why: nil),
                by: .player,
                now: now
            )
        let (active, taskID) = try paired
            .proposingVision(visionID, by: .player, now: now)
            .approvingVision(visionID, by: .manager, now: now)
            .creatingTask(title: "毎朝30分歩く", deadline: deadline, by: .manager, now: now)
        let state = try active.settingReaction(.angry, on: taskID, by: .player)

        // When
        let restored = try JSONDecoder().decode(
            PartnershipState.self, from: JSONEncoder().encode(state)
        )

        // Then
        #expect(restored == state)
    }
}
