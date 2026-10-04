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
    private let logger = Logger.sync

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
        return try decoding(record)
    }

    func save(_ state: PartnershipState, replacing base: PartnershipState) async throws(SyncFailure) {
        // 作り直したレコードで上書きすると、CKShare との結びつきを持つ
        // システムフィールドが落ちる。サーバーにあるものへ書き足す。
        guard let record = try await fetchRoot() else { throw .unavailable }
        let current = try decoding(record)
        guard current == base else { throw .outdated(latest: current) }

        let results: [CKRecord.ID: Result<CKRecord, any Error>]
        do {
            results = try await database.modifyRecords(
                saving: [PartnershipRootRecord.encoding(state, into: record)],
                deleting: [],
                savePolicy: .ifServerRecordUnchanged
            ).saveResults
        } catch {
            logger.error("save: \(error, privacy: .public)")
            throw .unavailable
        }
        switch results[rootRecordID] {
        case .success:
            return
        case .failure(let error as CKError) where error.code == .serverRecordChanged:
            guard let latest = error.serverRecord else {
                logger.error("save: 衝突したレコードが返っていない")
                throw .unavailable
            }
            throw .outdated(latest: try decoding(latest))
        case .failure(let error):
            logger.error("save: \(error, privacy: .public)")
            throw .unavailable
        case nil:
            logger.error("save: 保存したレコードの結果が返っていない")
            throw .unavailable
        }
    }
}

// MARK: - Private

private extension CloudKitSynchronizer {
    static let subscriptionID = "partnership-changes"

    func decoding(_ record: CKRecord) throws(SyncFailure) -> PartnershipState {
        do {
            return try PartnershipRootRecord.decoding(record)
        } catch {
            logger.error("decode: \(error, privacy: .public)")
            throw .unavailable
        }
    }

    func subscribe() async throws(SyncFailure) {
        // 同じ ID を保存し直すと拒否される。2回目からは張り直さない。
        if try await hasSubscription() { return }
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

    func hasSubscription() async throws(SyncFailure) -> Bool {
        do {
            _ = try await database.subscription(for: Self.subscriptionID)
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return false
        } catch {
            logger.error("subscription: \(error, privacy: .public)")
            throw .unavailable
        }
    }

    func fetchRoot() async throws(SyncFailure) -> CKRecord? {
        let results: [CKRecord.ID: Result<CKRecord, any Error>]
        do {
            results = try await database.records(for: [rootRecordID])
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            // ゾーンごと消えたときは、レコード単位ではなく取得そのものが失敗する。
            return nil
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
