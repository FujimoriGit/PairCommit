//
//  PairingOutcome.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

/// 成立したペア。
struct PairingOutcome: Sendable {
    let rootRecordID: RemoteRecordID
    let isOwner: Bool
}
