//
//  PartnershipInvitation.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import CloudKit
import Domain
import Foundation

struct PartnershipInvitation: PartnershipInviting {
    // MARK: 招待する側

    func send() async throws -> URL {
        let database = PartnershipShare.container.privateCloudDatabase
        // 前回のペアリングが途中で終わっていると、同じゾーンに共有が残っている。
        try await PartnershipShare.teardown(rootRecordID: PartnershipShare.ownedRootRecordID, isOwner: true)
        try await PartnershipShare.createZone(Self.invitationRecordID.zoneID, in: database)

        let invitation = CKRecord(recordType: Self.recordType, recordID: Self.invitationRecordID)
        let share = CKShare(rootRecord: invitation)
        share[CKShare.SystemFieldKey.title] = PartnershipShare.title as CKRecordValue
        share.publicPermission = .readWrite
        return try await PartnershipShare.saveSharing(invitation, with: share, in: database)
    }

    // 相手が招待リンクで参加していたら、その相手だけが参加できる共有をペアのルートレコードに作る。
    // 相手がそちらにも参加していたら、招待リンクの共有を消してペアの成立を返す。
    func advance(ownerRole: Role) async throws -> InvitationProgress {
        let database = PartnershipShare.container.privateCloudDatabase
        let rootRecordID = PartnershipShare.ownedRootRecordID
        if let root = try await PartnershipShare.fetchRoot(rootRecordID, from: database),
           let pairingShare = try await PartnershipShare.share(of: root, in: database) {
            if acceptedGuest(of: pairingShare) != nil {
                try await deleteInvitation(from: database)
                return .paired(.init(rootRecordID: .init(rootRecordID), isOwner: true))
            }
            let invitation = try await fetchInvitation(from: database)
            try await handOver(pairingShare.url, through: invitation, in: database)
            let invitationURL = try await url(of: invitation, in: database)
            return .waiting(invitationURL)
        }

        let invitation = try await fetchInvitation(from: database)
        guard let invitationShare = try await PartnershipShare.share(of: invitation, in: database),
              let invitationURL = invitationShare.url else {
            throw PartnershipShareError.shareURLUnavailable
        }
        guard let guest = acceptedGuest(of: invitationShare) else { return .waiting(invitationURL) }
        guard let userRecordID = guest.userIdentity.userRecordID else {
            throw PartnershipShareError.guestUnidentified
        }
        let participant = try await PartnershipShare.container.shareParticipant(forUserRecordID: userRecordID)
        participant.permission = .readWrite

        let paired = try PartnershipState().establishingPairing(ownerRole: ownerRole)
        let root = try PartnershipRootRecord.creating(paired, id: rootRecordID)
        let pairingShare = CKShare(rootRecord: root)
        pairingShare[CKShare.SystemFieldKey.title] = PartnershipShare.title as CKRecordValue
        pairingShare.publicPermission = .none
        pairingShare.addParticipant(participant)
        let pairingURL = try await PartnershipShare.saveSharing(root, with: pairingShare, in: database)
        try await handOver(pairingURL, through: invitation, in: database)
        return .waiting(invitationURL)
    }

    func withdraw() async throws {
        try await PartnershipShare.teardown(rootRecordID: PartnershipShare.ownedRootRecordID, isOwner: true)
    }

    // MARK: 招待を受ける側

    // 招待した側が、こちらだけが参加できる共有を用意していたら参加する。
    func advanceJoining(_ invitationID: RemoteRecordID) async throws -> PairingOutcome? {
        let recordID = CKRecord.ID(invitationID)
        let database = PartnershipShare.container.sharedCloudDatabase
        guard let invitation = try await PartnershipShare.fetchRoot(recordID, from: database) else {
            // 招待のレコードは、こちらがペアの共有に参加したのを見届けてから消される。
            let rootRecordID = pairingRootRecordID(besides: recordID)
            guard try await PartnershipShare.fetchRoot(rootRecordID, from: database) != nil else {
                throw PartnershipShareError.invitationWithdrawn
            }
            return .init(rootRecordID: .init(rootRecordID), isOwner: false)
        }
        guard let text = invitation[Key.pairingURL] as? String, let url = URL(string: text) else { return nil }
        let rootRecordID = try await PartnershipShare.accept(shareAt: url)
        return .init(rootRecordID: .init(rootRecordID), isOwner: false)
    }

    func leave(_ invitationID: RemoteRecordID) async throws {
        let recordID = CKRecord.ID(invitationID)
        let database = PartnershipShare.container.sharedCloudDatabase
        for rootID in [pairingRootRecordID(besides: recordID), recordID] {
            guard let root = try await PartnershipShare.fetchRoot(rootID, from: database),
                  let shareID = root.share?.recordID else { continue }
            let results = try await database.modifyRecords(saving: [], deleting: [shareID])
            try PartnershipShare.confirmDeleted(results.deleteResults[shareID])
        }
    }
}

// MARK: - Private

private extension PartnershipInvitation {
    static let recordType = "Invitation"

    static var invitationRecordID: CKRecord.ID {
        CKRecord.ID(recordName: "invitation", zoneID: PartnershipShare.ownedRootRecordID.zoneID)
    }

    func pairingRootRecordID(besides invitationID: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: PartnershipShare.ownedRootRecordID.recordName, zoneID: invitationID.zoneID)
    }

    enum Key {
        static let pairingURL = "pairingURL"
    }

    func acceptedGuest(of share: CKShare) -> CKShare.Participant? {
        share.participants.first { $0.role != .owner && $0.acceptanceStatus == .accepted }
    }

    func fetchInvitation(from database: CKDatabase) async throws -> CKRecord {
        guard let invitation = try await PartnershipShare.fetchRoot(Self.invitationRecordID, from: database) else {
            throw PartnershipShareError.invitationMissing
        }
        return invitation
    }

    func url(of invitation: CKRecord, in database: CKDatabase) async throws -> URL {
        guard let url = try await PartnershipShare.shareURL(of: invitation, in: database) else {
            throw PartnershipShareError.shareURLUnavailable
        }
        return url
    }

    func handOver(_ pairingURL: URL?, through invitation: CKRecord, in database: CKDatabase) async throws {
        guard let pairingURL else { throw PartnershipShareError.shareURLUnavailable }
        guard invitation[Key.pairingURL] as? String != pairingURL.absoluteString else { return }
        invitation[Key.pairingURL] = pairingURL.absoluteString as CKRecordValue
        _ = try await database.save(invitation)
    }

    func deleteInvitation(from database: CKDatabase) async throws {
        guard let invitation = try await PartnershipShare.fetchRoot(Self.invitationRecordID, from: database) else { return }
        let deleting = [invitation.share?.recordID, invitation.recordID].compactMap { $0 }
        let results = try await database.modifyRecords(saving: [], deleting: deleting)
        for id in deleting {
            try PartnershipShare.confirmDeleted(results.deleteResults[id])
        }
    }
}
