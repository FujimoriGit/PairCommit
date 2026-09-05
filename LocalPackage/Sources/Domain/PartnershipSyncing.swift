//
//  PartnershipSyncing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

public protocol PartnershipSyncing: Sendable {
    /// 相手の変更が届くようにしたうえで、いまの状態を返す。
    func start() async throws(SyncFailure) -> PartnershipState
    func load() async throws(SyncFailure) -> PartnershipState
    func save(_ state: PartnershipState) async throws(SyncFailure)
}
