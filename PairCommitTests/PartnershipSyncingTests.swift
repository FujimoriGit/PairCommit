//
//  PartnershipSyncingTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Application
import Domain
import Foundation
import Infrastructure
import Testing

struct InMemorySynchronizerTests {

    @Test("保存した状態はそのまま読み戻せる（load はローカル既知の最新を返す）")
    func savedStateRoundTripsThroughLoad() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        var state = PartnershipState()
        try state.establishPairing(ownerRole: .manager)

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
        var state = PartnershipState()
        try state.draftVision(statement: "s", doneCriteria: "c", by: .player)

        // When
        await synchronizer.simulateRemoteChange(state)

        // Then
        var iterator = stream.makeAsyncIterator()
        let received = await iterator.next()
        #expect(received == state)
    }
}

@MainActor
struct PartnershipStoreTests {

    @Test("操作はローカル状態へ即時反映され、リポジトリにも保存される（楽観適用）")
    func performAppliesMutationLocallyAndPersistsIt() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer)
        try await store.start()

        // When
        try await store.perform { try $0.draftVision(statement: "s", doneCriteria: "c", by: .player) }

        // Then
        #expect(store.state.visions.count == 1)
        let saved = await synchronizer.load()
        #expect(saved == store.state)
        store.stop()
    }

    @Test("ドメインルール違反は状態を一切変えずに呼び出し元へ投げ直される")
    func domainErrorLeavesStateUntouched() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(role: .manager, synchronizer: synchronizer)
        try await store.start()

        // When / Then
        await #expect(throws: DomainError.roleForbidden(required: .player)) {
            try await store.perform { try $0.draftVision(statement: "s", doneCriteria: "c", by: .manager) }
        }
        #expect(store.state == PartnershipState())
        store.stop()
    }

    @Test("相手側の変更は購読開始後に取りこぼしなく状態へ反映される")
    func remoteChangeUpdatesStoreState() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer)
        try await store.start()
        var remote = PartnershipState()
        try remote.establishPairing(ownerRole: .player)

        // When
        await synchronizer.simulateRemoteChange(remote)

        // Then
        for _ in 0..<1_000 where store.state != remote {
            await Task.yield()
        }
        #expect(store.state == remote)
        store.stop()
    }
}
