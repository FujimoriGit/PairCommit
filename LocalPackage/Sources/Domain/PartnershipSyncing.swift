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
    /// サーバーの状態が `base` のままのときだけ `state` で置き換える。
    /// 変わっていたら保存せず、サーバーの状態を載せて `SyncFailure.outdated` を投げる。
    func save(_ state: PartnershipState, replacing base: PartnershipState) async throws(SyncFailure)
}
