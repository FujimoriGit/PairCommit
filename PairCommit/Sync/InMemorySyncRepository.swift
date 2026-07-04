//
//  InMemorySyncRepository.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

/// CloudKit を待たずに本体を回すための最初の `SyncRepository` 実装。
/// プロセス内に状態を持つだけで、永続化も端末間同期もしない。
/// `simulateRemoteChange(_:)` で「相手側の変更」を注入できる（テスト・プレビュー用）。
actor InMemorySyncRepository: SyncRepository {
    private var state: PartnershipState
    private var subscribers: [UUID: AsyncStream<PartnershipState>.Continuation] = [:]

    init(initialState: PartnershipState = PartnershipState()) {
        state = initialState
    }

    func load() -> PartnershipState {
        state
    }

    func save(_ newState: PartnershipState) {
        state = newState
    }

    func remoteChanges() -> AsyncStream<PartnershipState> {
        AsyncStream { continuation in
            let id = UUID()
            subscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeSubscriber(id) }
            }
        }
    }

    /// 相手側の変更が届いたことをシミュレートする。
    func simulateRemoteChange(_ newState: PartnershipState) {
        state = newState
        for continuation in subscribers.values {
            continuation.yield(newState)
        }
    }
}

// MARK: - Private

private extension InMemorySyncRepository {
    func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }
}
