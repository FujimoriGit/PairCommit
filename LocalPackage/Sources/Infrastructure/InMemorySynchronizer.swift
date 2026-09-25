//
//  InMemorySynchronizer.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Domain

public actor InMemorySynchronizer: PartnershipSyncing {
    private var state: PartnershipState

    public init(initialState: PartnershipState = .init()) {
        state = initialState
    }

    public func start() -> PartnershipState {
        state
    }

    public func load() -> PartnershipState {
        state
    }

    public func save(_ newState: PartnershipState, replacing base: PartnershipState) throws(SyncFailure) {
        guard state == base else { throw .outdated(latest: state) }
        state = newState
    }
}
