//
//  CloudInviting.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Application
import CloudKit
import Domain
import Foundation

/// iCloud の共有の URL を招待リンクにして、離れた相手とペアを作る。
public struct CloudInviting: PartnershipInviting {
    private let shareTitle: String

    /// - Parameter shareTitle: 共有に付ける名前。相手が参加するときに目にする。
    public init(shareTitle: String) {
        self.shareTitle = shareTitle
    }

    public func send() async throws(PairingFailure) -> URL {
        try await translatingErrors {
            try await PartnershipInvitation.send(title: shareTitle)
        }
    }

    public func advance(ownerRole: Role) async throws(PairingFailure) -> InvitationProgress {
        try await translatingErrors { () async throws -> InvitationProgress in
            switch try await PartnershipInvitation.advance(ownerRole: ownerRole, title: shareTitle) {
            case .waiting(let url):
                return .waiting(url)
            case .paired(let rootRecordID):
                return .paired(CloudPairedShare(rootRecordID: rootRecordID, isOwner: true))
            }
        }
    }

    public func withdraw() async throws(PairingFailure) {
        try await translatingErrors {
            try await PartnershipInvitation.withdraw()
        }
    }

    public func join(_ link: URL) async throws(PairingFailure) {
        try await translatingErrors {
            let metadata = try await PartnershipShare.fetchMetadata(for: link)
            SavedInvitation.saveJoinedInvitationID(try await PartnershipInvitation.join(metadata))
        }
    }

    public func advanceJoining() async throws(PairingFailure) -> (any PairedShare)? {
        let invitationID = try joinedInvitationID()
        return try await translatingErrors {
            try await PartnershipInvitation.advanceJoining(invitationID).map {
                CloudPairedShare(rootRecordID: $0, isOwner: false)
            }
        }
    }

    public func leave() async throws(PairingFailure) {
        let invitationID = try joinedInvitationID()
        try await translatingErrors {
            try await PartnershipInvitation.leave(invitationID)
        }
    }

    public func endPair() async throws(PairingFailure) {
        try await translatingErrors {
            try await PartnershipInvitation.endPair(joining: SavedInvitation.joinedInvitationID())
        }
    }

    public func savedStep() -> InvitationStep? {
        SavedInvitation.loadStep()
    }

    public func savedWithdrawal() -> Withdrawal? {
        SavedInvitation.loadWithdrawal()
    }

    public func save(_ step: InvitationStep) {
        SavedInvitation.save(step)
    }

    public func save(_ withdrawal: Withdrawal) {
        SavedInvitation.save(withdrawal)
    }

    public func clearSaved() {
        SavedInvitation.clear()
    }
}

// MARK: - Private

private extension CloudInviting {
    func joinedInvitationID() throws(PairingFailure) -> CKRecord.ID {
        guard let invitationID = SavedInvitation.joinedInvitationID() else { throw .unexpected }
        return invitationID
    }

    func translatingErrors<T>(_ body: () async throws -> T) async throws(PairingFailure) -> T {
        do {
            return try await body()
        } catch {
            throw PairingFailure(error)
        }
    }
}
