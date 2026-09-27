//
//  PairedShare.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import CloudKit
import Domain

/// ペアの入った共有。どちらの方法でペアリングしても、これで同期を始め、ペアを終える。
struct PairedShare: Sendable {
    let rootRecordID: CKRecord.ID
    let isOwner: Bool

    func synchronizer() -> any PartnershipSyncing {
        CloudKitSynchronizer(rootRecordID: rootRecordID, isOwner: isOwner, container: PartnershipShare.container)
    }

    /// 相手の側でもペアが終わる。
    func end() async throws {
        try await PartnershipShare.teardown(rootRecordID: rootRecordID, isOwner: isOwner)
    }
}
