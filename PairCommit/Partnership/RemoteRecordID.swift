//
//  RemoteRecordID.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

/// 同期先に置いたレコードを指す。
struct RemoteRecordID: Hashable, Sendable {
    let recordName: String
    let zoneName: String
    let zoneOwnerName: String
}
