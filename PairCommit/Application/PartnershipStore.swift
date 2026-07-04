//
//  PartnershipStore.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation
import Observation

/// UI とドメインの結節点。この端末のロールで状態を操作し、`SyncRepository` 経由で保存・同期する。
/// 楽観適用: 操作はまずローカル状態に反映し、保存に失敗したら巻き戻して投げ直す。
@MainActor
@Observable
final class PartnershipStore {
    private(set) var state = PartnershipState()
    /// この端末のロール。ペアリング時に固定される。
    let role: Role

    private let repository: any SyncRepository
    private var observationTask: Task<Void, Never>?

    init(role: Role, repository: any SyncRepository) {
        self.role = role
        self.repository = repository
    }

    /// 保存済み状態を読み込み、相手側の変更の監視を開始する。
    func start() async throws {
        observationTask?.cancel()
        // 購読をロードより先に確立して、その間に届いた変更を取りこぼさない
        // （ストリームはバッファされるので、ロード後に消費が始まっても失われない）。
        let changes = await repository.remoteChanges()
        state = try await repository.load()
        observationTask = Task { [weak self] in
            for await remote in changes {
                guard let self else { break }
                self.state = remote
            }
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
    }

    /// ドメイン操作を適用して保存する。
    /// 例: `try await store.perform { try $0.reportTask(id, by: store.role) }`
    func perform(_ mutation: (inout PartnershipState) throws -> Void) async throws {
        let previous = state
        var next = state
        try mutation(&next)
        state = next
        do {
            try await repository.save(next)
        } catch {
            state = previous
            throw error
        }
    }
}
