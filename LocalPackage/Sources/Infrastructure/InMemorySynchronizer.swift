//
//  InMemorySynchronizer.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Domain
import Foundation

public actor InMemorySynchronizer: PartnershipSyncing {
    private var state: PartnershipState
    private var subscribers: [UUID: AsyncStream<PartnershipState>.Continuation] = [:]

    public init(initialState: PartnershipState = PartnershipState()) {
        state = initialState
    }

    public func load() -> PartnershipState {
        state
    }

    public func save(_ newState: PartnershipState) {
        state = newState
    }

    public func remoteChanges() -> AsyncStream<PartnershipState> {
        AsyncStream { continuation in
            let id = UUID()
            subscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeSubscriber(id) }
            }
        }
    }

    public func simulateRemoteChange(_ newState: PartnershipState) {
        state = newState
        for continuation in subscribers.values {
            continuation.yield(newState)
        }
    }
}

// MARK: - Private

private extension InMemorySynchronizer {
    func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }
}
