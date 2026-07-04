//
//  PairingShare.swift
//  PairCommit
//  
//  Created by Daiki Fujimori on 2026/06/20
//  


import CloudKit

enum PairingShareError: LocalizedError {
    case shareURLUnavailable
    case metadataMissing

    var errorDescription: String? {
        switch self {
        case .shareURLUnavailable: return "CKShareのURLが取得できなかった"
        case .metadataMissing:     return "共有メタデータが取得できなかった"
        }
    }
}

/// Spike: CloudKit Sharing の最小フロー。
/// オーナーが CKShare を作って URL を出し、参加者がその URL から受諾する。
/// 検証ポイント: システムの共有シート(UICloudSharingController)を経由せず、
/// URL文字列だけでプログラム受諾できるか。
enum PairingShare {
    static let container = CKContainer(identifier: "iCloud.com.daiki.paircommit")
    private static let zoneName = "PairingZone"
    private static let rootRecordName = "pairing-root"

    // MARK: Owner 側

    /// 共有ゾーンに Pairing レコードを作り、CKShare を生成して share URL を返す。
    static func makeShare() async throws -> URL {
        let db = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        // 共有はカスタムゾーンが前提。先に作っておく。
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await db.modifyRecordZones(saving: [zone], deleting: [])

        let pairing = CKRecord(
            recordType: "Pairing",
            recordID: CKRecord.ID(recordName: rootRecordName, zoneID: zoneID)
        )
        pairing["createdAt"] = Date() as CKRecordValue

        let share = CKShare(rootRecord: pairing)
        share[CKShare.SystemFieldKey.title] = "PairCommit" as CKRecordValue
        share.publicPermission = .none // 招待された相手だけが参加可能

        // ルートレコードと CKShare は同一オペレーションで原子的に保存する必要がある。
        _ = try await db.modifyRecords(saving: [pairing, share], deleting: [])

        guard let url = share.url else { throw PairingShareError.shareURLUnavailable }
        return url
    }

    // MARK: Participant 側

    /// URL からメタデータを引き、共有を受諾してゾーンに参加する。
    static func acceptShare(from url: URL) async throws {
        let metadata = try await fetchMetadata(for: url)
        try await accept(metadata)
    }
}

// MARK: - Private

private extension PairingShare {
    static func fetchMetadata(for url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let op = CKFetchShareMetadataOperation(shareURLs: [url])
            op.shouldFetchRootRecord = true
            var fetched: Result<CKShare.Metadata, Error>?
            op.perShareMetadataResultBlock = { _, result in fetched = result }
            op.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let fetched { continuation.resume(with: fetched) }
                    else { continuation.resume(throwing: PairingShareError.metadataMissing) }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(op)
        }
    }

    private static func accept(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
            var perShareError: Error?
            op.perShareResultBlock = { _, result in
                if case .failure(let error) = result { perShareError = error }
            }
            op.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    if let perShareError { continuation.resume(throwing: perShareError) }
                    else { continuation.resume() }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(op)
        }
    }
}
