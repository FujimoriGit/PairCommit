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

    var errorDescription: String? {
        switch self {
        case .shareURLUnavailable: return "CKShareのURLが取得できなかった"
        case .metadataMissing:     return "共有メタデータが取得できなかった"
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

        // CloudKit の共有はカスタムゾーンが前提。
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await database.modifyRecordZones(saving: [zone], deleting: [])

        let rootRecordID = CKRecord.ID(recordName: rootRecordName, zoneID: zoneID)
        let pairing = PartnershipRootRecord.encoding(initialState, id: rootRecordID)

        let share = CKShare(rootRecord: pairing)
        share[CKShare.SystemFieldKey.title] = "PairCommit" as CKRecordValue
        share.publicPermission = .none // 招待された相手だけが参加可能

        // ルートレコードと CKShare は同一オペレーションで原子的に保存する必要がある。
        _ = try await database.modifyRecords(saving: [pairing, share], deleting: [])

        guard let url = share.url else { throw PartnershipShareError.shareURLUnavailable }
        return (url, rootRecordID)
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
