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

    public init(role: Role, synchronizer: any PartnershipSyncing, state: PartnershipState) {
        self.role = role
        self.synchronizer = synchronizer
        self.state = state
    }

    public func refresh() async throws(SyncFailure) {
        state = try await synchronizer.load()
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
            // 保存を待つ間に取り直しが入っていたら、そちらが最新。自分の操作だけを取り消す。
            if state == next {
                state = previous
            }
            throw .notSynchronized(error)
        }
        // 後から書いた側が勝つので、保存できた時点でサーバーにあるのは next。
        state = next
    }
}
