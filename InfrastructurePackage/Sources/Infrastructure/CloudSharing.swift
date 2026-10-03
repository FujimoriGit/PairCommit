//
//  CloudSharing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import CloudKit
import Domain
import Foundation
import OSLog

/// iCloud の共有でペアを作る。
public struct CloudSharing: PartnershipSharing {
    private let shareTitle: String

    /// - Parameter shareTitle: 共有に付ける名前。相手が参加するときに目にする。
    public init(shareTitle: String) {
        self.shareTitle = shareTitle
    }

    public func makeShare(initialState: PartnershipState) async throws(PairingFailure) -> (url: URL, share: any PairedShare) {
        do {
            let made = try await PartnershipShare.makeShare(initialState: initialState, title: shareTitle)
            return (made.url, CloudPairedShare(rootRecordID: made.rootRecordID, isOwner: true))
        } catch {
            Logger.pairing.error("makeShare: \(error, privacy: .public)")
            throw PairingFailure(error)
        }
    }

    public func acceptShare(from url: URL) async throws(PairingFailure) -> any PairedShare {
        do {
            let rootRecordID = try await PartnershipShare.acceptShare(from: url)
            return CloudPairedShare(rootRecordID: rootRecordID, isOwner: false)
        } catch {
            Logger.pairing.error("acceptShare: \(error, privacy: .public)")
            throw PairingFailure(error)
        }
    }

    public func savedShare() -> (any PairedShare)? {
        SavedPairing.load()
    }

    public func clearSavedShare() {
        SavedPairing.clear()
    }
}

struct CloudPairedShare: PairedShare {
    let rootRecordID: CKRecord.ID
    let isOwner: Bool

    func synchronizer() -> any PartnershipSyncing {
        CloudKitSynchronizer(rootRecordID: rootRecordID, isOwner: isOwner, container: PartnershipShare.container)
    }

    func save() {
        SavedPairing.save(self)
    }

    func end() async throws(PairingFailure) {
        do {
            try await PartnershipShare.teardown(rootRecordID: rootRecordID, isOwner: isOwner)
        } catch {
            throw PairingFailure(error)
        }
    }
}

extension PairingFailure {
    init(_ error: any Error) {
        let cloudError = error as? CKError
        switch cloudError?.code {
        case .partialFailure:
            let reasons = cloudError?.partialErrorsByItemID?.values.map { Self($0) } ?? []
            self = reasons.first { $0 != .unexpected } ?? .unexpected
        case .notAuthenticated:
            self = .signedOut
        case .accountTemporarilyUnavailable:
            self = .accountUnverified
        case .quotaExceeded:
            self = .storageFull
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            self = .serverBusy
        case .networkUnavailable, .networkFailure:
            self = .offline
        default:
            self = .unexpected
        }
    }
}
