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
            .draftingVision(.init(statement: "半年で10kg痩せる", doneCriteria: "健康診断オールA", deadline: deadline), by: .player)
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
