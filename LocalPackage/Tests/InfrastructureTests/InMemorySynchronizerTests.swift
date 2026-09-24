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
        try await synchronizer.save(state, replacing: .init())

        // Then
        let loaded = await synchronizer.load()
        #expect(loaded == state)
    }

    @Test("もとにした状態から相手の保存で変わっていたら、保存せずに最新の状態を返す")
    func saveOverOutdatedBaseFailsWithTheLatestState() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let partners = try PartnershipState().establishingPairing(ownerRole: .manager)
        try await synchronizer.save(partners, replacing: .init())
        let mine = try PartnershipState().establishingPairing(ownerRole: .player)

        // When / Then
        await #expect(throws: SyncFailure.outdated(latest: partners)) {
            try await synchronizer.save(mine, replacing: .init())
        }
        let loaded = await synchronizer.load()
        #expect(loaded == partners)
    }
}
