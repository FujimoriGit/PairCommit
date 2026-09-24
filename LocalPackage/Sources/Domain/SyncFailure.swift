//
//  SyncFailure.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

public enum SyncFailure: Error, Equatable, Sendable {
    case unavailable
    /// 保存しようとした状態のもとにした状態から、相手の保存でサーバーの状態が変わっていた。
    case outdated(latest: PartnershipState)
}
