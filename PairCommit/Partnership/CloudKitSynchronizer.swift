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

public struct CloudKitSynchronizer {
    private let database: CKDatabase
    private let rootRecordID: CKRecord.ID
    private let remoteChangeSignals: @Sendable () async -> AsyncStream<Void>
    private let logger = Logger(subsystem: "com.fujimori.PairCommit", category: "sync")

    public init(
        rootRecordID: CKRecord.ID,
        isOwner: Bool,
        container: CKContainer,
        remoteChangeSignals: @escaping @Sendable () async -> AsyncStream<Void>
    ) {
        self.rootRecordID = rootRecordID
        self.database = isOwner ? container.privateCloudDatabase : container.sharedCloudDatabase
        self.remoteChangeSignals = remoteChangeSignals
    }
}

// MARK: - PartnershipSyncing

extension CloudKitSynchronizer: PartnershipSyncing {
    public func load() async throws(SyncFailure) -> PartnershipState {
        guard let record = try await fetchRoot() else { return .init() }
        return PartnershipRootRecord.decoding(record) ?? .init()
    }

    public func save(_ state: PartnershipState) async throws(SyncFailure) {
        // 作り直したレコードで上書きすると、CKShare との結びつきを持つ
        // システムフィールドが落ちる。サーバーにあるものへ書き足す。
        let base = try await fetchRoot()
        do {
            // .allKeys は変更タグを見ずに上書きする。後から書いた側が勝つ。
            _ = try await database.modifyRecords(
                saving: [PartnershipRootRecord.encoding(state, id: rootRecordID, base: base)],
                deleting: [],
                savePolicy: .allKeys
            )
        } catch {
            logger.error("save: \(error, privacy: .public)")
            throw .unavailable
        }
    }

    public func remoteChanges() async -> AsyncStream<PartnershipState> {
        AsyncStream { continuation in
            let delivery = Task {
                for await _ in await remoteChangeSignals() {
                    guard let state = try? await load() else { continue }
                    continuation.yield(state)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in delivery.cancel() }
        }
    }
}

public extension CloudKitSynchronizer {
    /// 相手側の変更でプッシュが飛ぶようにする。届いたプッシュは `remoteChangeSignals` へ流すこと。
    func subscribeToRemoteChanges() async throws(SyncFailure) {
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
}

// MARK: - Private

private extension CloudKitSynchronizer {
    static let subscriptionID = "partnership-changes"

    func fetchRoot() async throws(SyncFailure) -> CKRecord? {
        let results: [CKRecord.ID: Result<CKRecord, any Error>]
        do {
            results = try await database.records(for: [rootRecordID])
        } catch {
            logger.error("fetch: \(error, privacy: .public)")
            throw .unavailable
        }
        guard case .success(let record) = results[rootRecordID] else { return nil }
        return record
    }
}
