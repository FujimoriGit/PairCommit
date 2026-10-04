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
            throw PairingFailure(error)
        }
    }

    public func acceptShare(from url: URL) async throws(PairingFailure) -> any PairedShare {
        do {
            let rootRecordID = try await PartnershipShare.acceptShare(from: url)
            return CloudPairedShare(rootRecordID: rootRecordID, isOwner: false)
        } catch {
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
        Logger.pairing.error("\(error, privacy: .public)")
        self = Self.classifying(error)
    }
}

// MARK: - Private

private extension PairingFailure {
    static func classifying(_ error: any Error) -> Self {
        if case .invitationWithdrawn? = error as? PartnershipShareError {
            return .invitationWithdrawn
        }
        let cloudError = error as? CKError
        switch cloudError?.code {
        case .partialFailure:
            let reasons = cloudError?.partialErrorsByItemID?.values.map(classifying) ?? []
            return reasons.first { $0 != .unexpected } ?? .unexpected
        case .notAuthenticated:
            return .signedOut
        case .accountTemporarilyUnavailable:
            return .accountUnverified
        case .quotaExceeded:
            return .storageFull
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .serverBusy
        case .networkUnavailable, .networkFailure:
            return .offline
        default:
            return .unexpected
        }
    }
}
