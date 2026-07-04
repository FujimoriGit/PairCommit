//
//  SyncRepositoryTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation
import Testing
@testable import PairCommit

/// `InMemorySyncRepository` と `PartnershipStore` の結合テスト。
struct SyncRepositoryTests {

    @Test func 保存した状態がロードできる() async throws {
        let repository = InMemorySyncRepository()
        var state = PartnershipState()
        try state.establishPairing(ownerRole: .manager)

        try await repository.save(state)
        let loaded = try await repository.load()
        #expect(loaded == state)
    }

    @Test func リモート変更がストリームに届く() async throws {
        let repository = InMemorySyncRepository()
        let stream = await repository.remoteChanges()

        var state = PartnershipState()
        try state.draftVision(statement: "s", doneCriteria: "c", by: .player)
        await repository.simulateRemoteChange(state)

        var iterator = stream.makeAsyncIterator()
        let received = await iterator.next()
        #expect(received == state)
    }
}

@MainActor
struct PartnershipStoreTests {

    @Test func 操作はローカルに反映され保存される() async throws {
        let repository = InMemorySyncRepository()
        let store = PartnershipStore(role: .player, repository: repository)
        try await store.start()

        try await store.perform { try $0.draftVision(statement: "s", doneCriteria: "c", by: .player) }

        #expect(store.state.visions.count == 1)
        let saved = try await repository.load()
        #expect(saved == store.state)
        store.stop()
    }

    @Test func ドメインエラーは状態を変えずに投げ直される() async throws {
        let repository = InMemorySyncRepository()
        let store = PartnershipStore(role: .manager, repository: repository)
        try await store.start()

        await #expect(throws: DomainError.roleForbidden(required: .player)) {
            try await store.perform { try $0.draftVision(statement: "s", doneCriteria: "c", by: .manager) }
        }
        #expect(store.state == PartnershipState())
        store.stop()
    }

    @Test func リモート変更が状態に反映される() async throws {
        let repository = InMemorySyncRepository()
        let store = PartnershipStore(role: .player, repository: repository)
        try await store.start()

        var remote = PartnershipState()
        try remote.establishPairing(ownerRole: .player)
        await repository.simulateRemoteChange(remote)

        for _ in 0..<1_000 where store.state != remote {
            await Task.yield()
        }
        #expect(store.state == remote)
        store.stop()
    }
}
