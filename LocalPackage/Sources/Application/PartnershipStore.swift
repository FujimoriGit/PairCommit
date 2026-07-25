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

    public init(role: Role, synchronizer: any PartnershipSyncing) {
        self.role = role
        self.synchronizer = synchronizer
    }

    public func start() async throws {
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

    public func perform(_ transform: (PartnershipState) throws -> PartnershipState) async throws {
        let previous = state
        let next = try transform(state)
        state = next
        do {
            try await synchronizer.save(next)
        } catch {
            state = previous
            throw error
        }
    }
}
