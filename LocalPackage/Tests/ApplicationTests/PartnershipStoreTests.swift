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
        synchronizer.hold()

        // When
        let performing = Task {
            try await store.perform { state throws(DomainError) in
                try state.draftingVision(statement: "s", doneCriteria: "c", by: .player).state
            }
        }
        await Task.yield()
        let refreshing = Task { try await store.refresh() }
        await Task.yield()
        synchronizer.release()
        try await performing.value
        try await refreshing.value

        // Then
        #expect(store.state.visions.count == 1)
    }

    @Test("保存が重なっても、あとから始めた操作は消えない")
    func overlappingPerformsKeepBothChanges() async throws {
        // Given
        let synchronizer = InterruptibleSynchronizer()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())
        synchronizer.hold()

        // When
        let first = Task {
            try await store.perform { state throws(DomainError) in
                try state.draftingVision(statement: "s1", doneCriteria: "c1", by: .player).state
            }
        }
        await Task.yield()
        let second = Task {
            try await store.perform { state throws(DomainError) in
                try state.draftingVision(statement: "s2", doneCriteria: "c2", by: .player).state
            }
        }
        await Task.yield()
        synchronizer.release()
        try await first.value
        try await second.value

        // Then
        #expect(store.state.visions.count == 2)
        #expect(synchronizer.stored == store.state)
    }

    @Test("保存に失敗した操作は、状態を元へ戻して呼び出し元へ投げ直される")
    func failedSaveRollsBackTheChange() async throws {
        // Given
        let synchronizer = InterruptibleSynchronizer()
        synchronizer.failure = .unavailable
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())

        // When / Then
        await #expect(throws: PartnershipFailure.notSynchronized(.unavailable)) {
            try await store.perform { state throws(DomainError) in
                try state.draftingVision(statement: "s", doneCriteria: "c", by: .player).state
            }
        }
        #expect(store.state == PartnershipState())
    }
}

/// 保存を止めておける同期層。保存が重なった状況を作るために使う。
@MainActor
private final class InterruptibleSynchronizer: PartnershipSyncing {
    var stored: PartnershipState = .init()
    var failure: SyncFailure?

    private var held = false
    private var waiting: CheckedContinuation<Void, Never>?

    func hold() {
        held = true
    }

    func release() {
        held = false
        waiting?.resume()
        waiting = nil
    }

    func start() -> PartnershipState {
        stored
    }

    func load() -> PartnershipState {
        stored
    }

    func save(_ state: PartnershipState) async throws(SyncFailure) {
        if held {
            await withCheckedContinuation { waiting = $0 }
        }
        if let failure {
            throw failure
        }
        stored = state
    }
}
