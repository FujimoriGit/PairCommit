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
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())

        // When
        try await store.perform { state throws(DomainError) in
            try state.draftingVision(statement: "s", doneCriteria: "c", by: .player).state
        }

        // Then
        #expect(store.state.visions.count == 1)
        let saved = await synchronizer.load()
        #expect(saved == store.state)
    }

    @Test("ドメインルール違反は状態を一切変えずに呼び出し元へ投げ直される")
    func domainErrorLeavesStateUntouched() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(role: .manager, synchronizer: synchronizer, state: .init())

        // When / Then
        await #expect(throws: PartnershipFailure.rejected(.roleForbidden(required: .player))) {
            try await store.perform { state throws(DomainError) in
                try state.draftingVision(statement: "s", doneCriteria: "c", by: .manager).state
            }
        }
        #expect(store.state == PartnershipState())
    }

    @Test("相手側の変更は、取り直したときに状態へ反映される")
    func remoteChangeAppearsAfterRefresh() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())
        let remote = try PartnershipState().establishingPairing(ownerRole: .player)
        await synchronizer.save(remote)

        // When
        try await store.refresh()

        // Then
        #expect(store.state == remote)
    }

    @Test("保存を待つ間に相手の変更を取り直しても、保存できた自分の操作は消えない")
    func refreshDuringSaveKeepsTheSavedChange() async throws {
        // Given
        let synchronizer = InterruptibleSynchronizer()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())
        synchronizer.stored = try PartnershipState().establishingPairing(ownerRole: .player)
        synchronizer.duringSave = { [store] in try? await store.refresh() }

        // When
        try await store.perform { state throws(DomainError) in
            try state.draftingVision(statement: "s", doneCriteria: "c", by: .player).state
        }

        // Then
        #expect(store.state.visions.count == 1)
    }

    @Test("保存に失敗したときの巻き戻しは、待つ間に取り直した相手の変更までは消さない")
    func failedSaveKeepsTheRefreshedRemoteChange() async throws {
        // Given
        let synchronizer = InterruptibleSynchronizer()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())
        let remote = try PartnershipState().establishingPairing(ownerRole: .player)
        synchronizer.stored = remote
        synchronizer.failure = .unavailable
        synchronizer.duringSave = { [store] in try? await store.refresh() }

        // When / Then
        await #expect(throws: PartnershipFailure.notSynchronized(.unavailable)) {
            try await store.perform { state throws(DomainError) in
                try state.draftingVision(statement: "s", doneCriteria: "c", by: .player).state
            }
        }
        #expect(store.state == remote)
    }
}

/// 保存の途中に割り込みを差し込める同期層。
@MainActor
private final class InterruptibleSynchronizer: PartnershipSyncing {
    var stored: PartnershipState = .init()
    var failure: SyncFailure?
    var duringSave: (() async -> Void)?

    func start() -> PartnershipState {
        stored
    }

    func load() -> PartnershipState {
        stored
    }

    func save(_ state: PartnershipState) async throws(SyncFailure) {
        await duringSave?()
        if let failure {
            throw failure
        }
        stored = state
    }
}
