//
//  CloudKitSynchronizer.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/29
//

import CloudKit
import Domain
import Foundation
import OSLog

struct CloudKitSynchronizer {
    private let database: CKDatabase
    private let rootRecordID: CKRecord.ID
    private let logger = Logger(subsystem: "com.fujimori.PairCommit", category: "sync")

    init(rootRecordID: CKRecord.ID, isOwner: Bool, container: CKContainer) {
        self.rootRecordID = rootRecordID
        self.database = isOwner ? container.privateCloudDatabase : container.sharedCloudDatabase
    }
}

// MARK: - PartnershipSyncing

extension CloudKitSynchronizer: PartnershipSyncing {
    func start() async throws(SyncFailure) -> PartnershipState {
        try await subscribe()
        return try await load()
    }

    func load() async throws(SyncFailure) -> PartnershipState {
        guard let record = try await fetchRoot() else { return .init() }
        do {
            return try PartnershipRootRecord.decoding(record)
        } catch {
            logger.error("decode: \(error, privacy: .public)")
            throw .unavailable
        }
    }

    func save(_ state: PartnershipState) async throws(SyncFailure) {
        // 作り直したレコードで上書きすると、CKShare との結びつきを持つ
        // システムフィールドが落ちる。サーバーにあるものへ書き足す。
        guard let base = try await fetchRoot() else { throw .unavailable }
        do {
            _ = try await database.modifyRecords(
                saving: [PartnershipRootRecord.encoding(state, into: base)],
                deleting: [],
                savePolicy: .allKeys
            )
        } catch {
            logger.error("save: \(error, privacy: .public)")
            throw .unavailable
        }
    }
}

// MARK: - Private

private extension CloudKitSynchronizer {
    static let subscriptionID = "partnership-changes"

    func subscribe() async throws(SyncFailure) {
        let subscription = CKDatabaseSubscription(subscriptionID: Self.subscriptionID)
        let info = CKSubscription.NotificationInfo()
        // 催促以外で相手の画面に何か出したいわけではないので、通知は出さず起こすだけにする。
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        do {
            _ = try await database.modifySubscriptions(saving: [subscription], deleting: [])
        } catch {
            logger.error("subscribe: \(error, privacy: .public)")
            throw .unavailable
        }
    }

    func fetchRoot() async throws(SyncFailure) -> CKRecord? {
        let results: [CKRecord.ID: Result<CKRecord, any Error>]
        do {
            results = try await database.records(for: [rootRecordID])
        } catch {
            logger.error("fetch: \(error, privacy: .public)")
            throw .unavailable
        }
        switch results[rootRecordID] {
        case .success(let record):
            return record
        case .failure(let error):
            // 不在は終了の合図なので、読めなかっただけの失敗と同じ値にはできない。
            guard (error as? CKError)?.code == .unknownItem else {
                logger.error("fetch: \(error, privacy: .public)")
                throw .unavailable
            }
            return nil
        case nil:
            logger.error("fetch: 要求したレコードの結果が返っていない")
            throw .unavailable
        }
    }
}
