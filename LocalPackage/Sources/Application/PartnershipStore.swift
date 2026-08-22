//
//  PartnershipStore.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class PartnershipStore {
    public private(set) var state = PartnershipState()
    public let role: Role

    private let synchronizer: any PartnershipSyncing
    private var observationTask: Task<Void, Never>?

    public init(role: Role, synchronizer: any PartnershipSyncing, state: PartnershipState = .init()) {
        self.role = role
        self.synchronizer = synchronizer
        self.state = state
    }

    public func start() async throws(SyncFailure) {
        observationTask?.cancel()
        let changes = await synchronizer.remoteChanges()
        state = try await synchronizer.load()
        observationTask = Task { [weak self] in
            for await remote in changes {
                guard let self else { break }
                self.state = remote
            }
        }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
    }

    public func perform(
        _ transform: (PartnershipState) throws(DomainError) -> PartnershipState
    ) async throws(PartnershipFailure) {
        let previous = state
        let next: PartnershipState
        do {
            next = try transform(state)
        } catch {
            throw .rejected(error)
        }
        state = next
        do {
            try await synchronizer.save(next)
        } catch {
            state = previous
            throw .notSynchronized(error)
        }
    }
}
