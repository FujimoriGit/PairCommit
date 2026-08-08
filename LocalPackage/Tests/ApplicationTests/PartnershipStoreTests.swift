//
//  PartnershipStoreTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Application
import Domain
import Foundation
import Infrastructure
import Testing

@MainActor
struct PartnershipStoreTests {

    @Test("操作はローカル状態へ即時反映され、同期層にも保存される（楽観適用）")
    func performAppliesChangeLocallyAndPersistsIt() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer)
        try await store.start()

        // When
        try await store.perform {
            try $0.draftingVision(statement: "s", doneCriteria: "c", by: .player).state
        }

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
            try await store.perform {
                try $0.draftingVision(statement: "s", doneCriteria: "c", by: .manager).state
            }
        }
        #expect(store.state == PartnershipState())
        store.stop()
    }

    @Test("渡された初期状態は、同期層から読み込む前でも見えている")
    func initialStateIsVisibleBeforeStart() throws {
        // Given
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)

        // When
        let store = PartnershipStore(role: .manager, synchronizer: InMemorySynchronizer(), state: paired)

        // Then
        #expect(store.state == paired)
    }

    @Test("相手側の変更は購読開始後に取りこぼしなく状態へ反映される")
    func remoteChangeUpdatesStoreState() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer)
        try await store.start()
        let remote = try PartnershipState().establishingPairing(ownerRole: .player)

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
