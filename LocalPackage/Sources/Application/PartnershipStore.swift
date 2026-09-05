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
    public private(set) var state: PartnershipState
    public let role: Role

    private let synchronizer: any PartnershipSyncing
    private var pending: Task<Void, Never>?

    public init(role: Role, synchronizer: any PartnershipSyncing, state: PartnershipState) {
        self.role = role
        self.synchronizer = synchronizer
        self.state = state
    }

    public func refresh() async throws(SyncFailure) {
        let failure = await serialized { [self] () -> SyncFailure? in
            do throws(SyncFailure) {
                state = try await synchronizer.load()
                return nil
            } catch {
                return error
            }
        }
        if let failure {
            throw failure
        }
    }

    public func perform(
        _ transform: @escaping @Sendable (PartnershipState) throws(DomainError) -> PartnershipState
    ) async throws(PartnershipFailure) {
        let failure = await serialized { [self] () -> PartnershipFailure? in
            let previous = state
            let next: PartnershipState
            do throws(DomainError) {
                next = try transform(state)
            } catch {
                return .rejected(error)
            }
            state = next
            do throws(SyncFailure) {
                try await synchronizer.save(next)
                return nil
            } catch {
                state = previous
                return .notSynchronized(error)
            }
        }
        if let failure {
            throw failure
        }
    }
}

// MARK: - Private

private extension PartnershipStore {
    // 保存と取り直しを1件ずつ流す。重ねると、サーバーに着く順とローカルの順が食い違う。
    func serialized<T: Sendable>(_ body: @escaping @MainActor () async -> T) async -> T {
        let queued = pending
        let turn = Task { @MainActor in
            await queued?.value
            return await body()
        }
        pending = Task { _ = await turn.value }
        return await turn.value
    }
}
