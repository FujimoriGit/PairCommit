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

    @Test("相手側の変更は remoteChanges のストリームに届く")
    func remoteChangeIsDeliveredToSubscribers() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let stream = await synchronizer.remoteChanges()
        let (state, _) = try PartnershipState().draftingVision(
            statement: "s", doneCriteria: "c", by: .player
        )

        // When
        await synchronizer.simulateRemoteChange(state)

        // Then
        var iterator = stream.makeAsyncIterator()
        let received = await iterator.next()
        #expect(received == state)
    }
}
