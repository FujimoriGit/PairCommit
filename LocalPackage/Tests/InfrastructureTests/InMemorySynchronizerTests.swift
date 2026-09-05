//
//  InMemorySynchronizerTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/07/26
//

import Domain
import Foundation
import Infrastructure
import Testing

struct InMemorySynchronizerTests {

    @Test("保存した状態はそのまま読み戻せる（load はローカル既知の最新を返す）")
    func savedStateRoundTripsThroughLoad() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let state = try PartnershipState().establishingPairing(ownerRole: .manager)

        // When
        await synchronizer.save(state)

        // Then
        let loaded = await synchronizer.load()
        #expect(loaded == state)
    }

    @Test("開始したときに返るのは、保存済みの最新の状態")
    func startReturnsLatestSavedState() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let state = try PartnershipState().establishingPairing(ownerRole: .player)
        await synchronizer.save(state)

        // When
        let started = await synchronizer.start()

        // Then
        #expect(started == state)
    }
}
