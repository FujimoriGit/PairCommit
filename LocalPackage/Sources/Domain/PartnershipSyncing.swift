//
//  PartnershipSyncing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

public protocol PartnershipSyncing: Sendable {
    func load() async throws(SyncFailure) -> PartnershipState
    func save(_ state: PartnershipState) async throws(SyncFailure)
    func remoteChanges() async -> AsyncStream<PartnershipState>
}
