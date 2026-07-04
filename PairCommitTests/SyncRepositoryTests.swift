//
//  SyncRepositoryTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Application
import Domain
import Foundation
import Testing

/// `SyncRepository` のセマンティクス（保存・読み込み・リモート変更の配信）を検証する。
struct InMemorySyncRepositoryTests {

    @Test("保存した状態はそのまま読み戻せる（load はローカル既知の最新を返す）")
    func savedStateRoundTripsThroughLoad() async throws {
        // Given
        let repository = InMemorySyncRepository()
        var state = PartnershipState()
        try state.establishPairing(ownerRole: .manager)

        // When
        await repository.save(state)

        // Then
        let loaded = await repository.load()
        #expect(loaded == state)
    }

    @Test("相手側の変更は remoteChanges のストリームに届く")
    func remoteChangeIsDeliveredToSubscribers() async throws {
        // Given
        let repository = InMemorySyncRepository()
        let stream = await repository.remoteChanges()
        var state = PartnershipState()
        try state.draftVision(statement: "s", doneCriteria: "c", by: .player)

        // When
        await repository.simulateRemoteChange(state)

        // Then
        var iterator = stream.makeAsyncIterator()
        let received = await iterator.next()
        #expect(received == state)
    }
}

/// `PartnershipStore`（UIとドメインの結節点）の振る舞いを検証する。
@MainActor
struct PartnershipStoreTests {

    @Test("操作はローカル状態へ即時反映され、リポジトリにも保存される（楽観適用）")
    func performAppliesMutationLocallyAndPersistsIt() async throws {
        // Given
        let repository = InMemorySyncRepository()
        let store = PartnershipStore(role: .player, repository: repository)
        try await store.start()

        // When
        try await store.perform { try $0.draftVision(statement: "s", doneCriteria: "c", by: .player) }

        // Then
        #expect(store.state.visions.count == 1)
        let saved = await repository.load()
        #expect(saved == store.state)
        store.stop()
    }

    @Test("ドメインルール違反は状態を一切変えずに呼び出し元へ投げ直される")
    func domainErrorLeavesStateUntouched() async throws {
        // Given
        let repository = InMemorySyncRepository()
        let store = PartnershipStore(role: .manager, repository: repository)
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
        let repository = InMemorySyncRepository()
        let store = PartnershipStore(role: .player, repository: repository)
        try await store.start()
        var remote = PartnershipState()
        try remote.establishPairing(ownerRole: .player)

        // When
        await repository.simulateRemoteChange(remote)

        // Then
        for _ in 0..<1_000 where store.state != remote {
            await Task.yield()
        }
        #expect(store.state == remote)
        store.stop()
    }
}
