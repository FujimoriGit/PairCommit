//
//  SyncRepository.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

/// 同期層のセマンティクス境界。ドメインはこのプロトコルとだけ会話し、CloudKit の存在を知らない。
/// CloudKit（第一期）も自作バックエンド（第二期）も「もう一つの実装」として差し替えられる。
///
/// 実装が保証すべきセマンティクス:
/// - `load()` はローカルに既知の最新状態を返す（オフラインでも失敗しない実装が望ましい）。
/// - `save(_:)` が正常終了した状態は、いずれ相手側に届く（結果整合）。
/// - `remoteChanges()` は相手側の変更を反映した状態全体を届ける。
///   順序は保証するが、途中の状態は合流（coalesce）されることがある。
public protocol SyncRepository: Sendable {
    func load() async throws -> PartnershipState
    func save(_ state: PartnershipState) async throws
    func remoteChanges() async -> AsyncStream<PartnershipState>
}
