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

    @Test("一度ペアを組んだら、組み直して役割を入れ替えることはできない")
    func aPairCannotBeFormedTwice() throws {
        // Given
        let state = try PartnershipState().establishingPairing(ownerRole: .manager)

        // When / Then
        #expect(throws: DomainError.alreadyPaired) {
            try state.establishingPairing(ownerRole: .player)
        }
    }

    // MARK: - タスクへの気持ち

    @Test("挑む人がタスクへの気持ちを付け直すと、最後に付けた気持ちだけが残る")
    func onlyTheLatestFeelingOnATaskRemains() throws {
        // Given
        let (active, taskID) = try PartnershipState().activeVisionWithTask()
        let state = try active.settingReaction(.uneasy, on: taskID, by: .player)

        // When
        let changed = try state.settingReaction(.happy, on: taskID, by: .player)

        // Then
        #expect(changed.tasks.first?.reaction == .happy)
    }

    @Test("挑む人は、タスクに付けた気持ちを外せる")
    func playerCanTakeBackAFeelingOnATask() throws {
        // Given
        let (active, taskID) = try PartnershipState().activeVisionWithTask()
        let state = try active.settingReaction(.uneasy, on: taskID, by: .player)

        // When
        let cleared = try state.settingReaction(nil, on: taskID, by: .player)

        // Then
        #expect(cleared.tasks.first?.reaction == nil)
    }

    @Test("タスクへの気持ちを表明できるのは挑む人だけ")
    func onlyPlayerCanExpressAFeelingOnATask() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.settingReaction(.angry, on: taskID, by: .manager)
        }
    }

    // MARK: - iCloud への保存

    @Test("iCloud に保存して読み直しても、ペアの状態は何も失われない")
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
