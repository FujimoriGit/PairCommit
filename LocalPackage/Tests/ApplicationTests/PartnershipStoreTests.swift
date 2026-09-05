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

    @Test("開始時に渡された状態は、同期層を読みに行かなくても見えている")
    func initialStateIsVisibleWithoutLoading() throws {
        // Given
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)

        // When
        let store = PartnershipStore(role: .manager, synchronizer: InMemorySynchronizer(), state: paired)

        // Then
        #expect(store.state == paired)
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
}
