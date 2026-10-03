//
//  InMemorySynchronizer.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Domain

actor InMemorySynchronizer: PartnershipSyncing {
    private var state: PartnershipState

    init(initialState: PartnershipState = .init()) {
        state = initialState
    }

    func start() -> PartnershipState {
        state
    }

    func load() -> PartnershipState {
        state
    }

    func save(_ newState: PartnershipState, replacing base: PartnershipState) throws(SyncFailure) {
        guard state == base else { throw .outdated(latest: state) }
        state = newState
    }
}
