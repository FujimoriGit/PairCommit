//
//  PartnershipShare.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import CloudKit
import Domain
import Foundation

enum PartnershipShareError: LocalizedError {
    case shareURLUnavailable
    case metadataMissing
    case deleteResultMissing

    var errorDescription: String? {
        switch self {
        case .shareURLUnavailable:  return "CKShareのURLが取得できなかった"
        case .metadataMissing:      return "共有メタデータが取得できなかった"
        case .deleteResultMissing:  return "削除した結果が返ってこなかった"
        }
    }
}

enum PartnershipShare {
    static let container = CKContainer(identifier: "iCloud.com.fujimori.PairCommit")
    private static let zoneName = "PairingZone"
    private static let rootRecordName = "pairing-root"

    // MARK: Owner 側

    static func makeShare(initialState: PartnershipState) async throws -> (url: URL, rootRecordID: CKRecord.ID) {
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let rootRecordID = CKRecord.ID(recordName: rootRecordName, zoneID: zoneID)

        // ゾーン名もレコード名も固定なので、前回のペアリングが途中で失敗していると共有が残っている。
        // 相手が受け終えて ACK だけが届かなかったときに同じ共有へつなぎ直せるよう、役割が同じなら残す。
        // 読めないレコードは役割を確かめられないので、作り直す側に倒す。
        if let existing = try await fetchRoot(rootRecordID, from: database) {
            let existingRole = try? PartnershipRootRecord.decoding(existing).pairing?.ownerRole
            if existingRole == initialState.pairing?.ownerRole,
               let url = try await shareURL(of: existing, in: database) {
                return (url, rootRecordID)
            }
            let deleted = try await database.modifyRecordZones(saving: [], deleting: [zoneID])
            try confirmDeleted(deleted.deleteResults[zoneID])
        }

        // CloudKit の共有はカスタムゾーンが前提。
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        let pairing = try PartnershipRootRecord.creating(initialState, id: rootRecordID)

        let share = CKShare(rootRecord: pairing)
        share[CKShare.SystemFieldKey.title] = "ふたりの帆柱" as CKRecordValue
        // 参加者を名指しで招待する仕組みを持たない。URL を知っている人が参加でき、
        // ルートレコードを書ける必要がある。
        share.publicPermission = .readWrite

        // ルートレコードと CKShare は同一オペレーションで原子的に保存する必要がある。
        _ = try await database.modifyRecords(saving: [pairing, share], deleting: [])

        guard let url = share.url else { throw PartnershipShareError.shareURLUnavailable }
        return (url, rootRecordID)
    }

    // MARK: 両者共通

    static func teardown(rootRecordID: CKRecord.ID, isOwner: Bool) async throws {
        do {
            guard isOwner else {
                let results = try await container.sharedCloudDatabase.modifyRecords(
                    saving: [],
                    deleting: [rootRecordID]
                )
                try confirmDeleted(results.deleteResults[rootRecordID])
                return
            }
            let results = try await container.privateCloudDatabase.modifyRecordZones(
                saving: [],
                deleting: [rootRecordID.zoneID]
            )
            try confirmDeleted(results.deleteResults[rootRecordID.zoneID])
        } catch let error as CKError where absent.contains(error.code) {
            return
        }
    }

    // MARK: Participant 側

    static func acceptShare(from url: URL) async throws -> CKRecord.ID {
        let metadata = try await fetchMetadata(for: url)
        try await accept(metadata)
        // 共有ゾーンの ownerName は相手のものになるため、参加者側で組み立て直せない。
        guard let rootRecordID = metadata.hierarchicalRootRecordID else {
            throw PartnershipShareError.metadataMissing
        }
        return rootRecordID
    }
}

// MARK: - Private

private extension PartnershipShare {
    static let absent: Set<CKError.Code> = [.zoneNotFound, .userDeletedZone, .unknownItem]

    // 消せたかどうかは項目ごとの結果に入る。オペレーション自体が投げるのは、そこへ辿り着けなかったとき。
    static func confirmDeleted(_ result: Result<Void, any Error>?) throws {
        guard let result else { throw PartnershipShareError.deleteResultMissing }
        guard case .failure(let error) = result else { return }
        guard let code = (error as? CKError)?.code, absent.contains(code) else { throw error }
    }

    static func fetchRoot(_ id: CKRecord.ID, from database: CKDatabase) async throws -> CKRecord? {
        do {
            return try await database.record(for: id)
        } catch let error as CKError where absent.contains(error.code) {
            return nil
        }
    }

    static func shareURL(of root: CKRecord, in database: CKDatabase) async throws -> URL? {
        guard let shareID = root.share?.recordID,
              let share = try await database.record(for: shareID) as? CKShare else { return nil }
        return share.url
    }

    static func fetchMetadata(for url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.shouldFetchRootRecord = true
            var fetched: Result<CKShare.Metadata, Error>?
            operation.perShareMetadataResultBlock = { _, result in fetched = result }
            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let fetched {
                        continuation.resume(with: fetched)
                    } else {
                        continuation.resume(throwing: PartnershipShareError.metadataMissing)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    static func accept(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            var perShareError: Error?
            operation.perShareResultBlock = { _, result in
                if case .failure(let error) = result { perShareError = error }
            }
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    if let perShareError {
                        continuation.resume(throwing: perShareError)
                    } else {
                        continuation.resume()
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }
}
