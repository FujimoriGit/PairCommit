//
//  PartnershipInvitation.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import CloudKit
import Domain
import Foundation

/// 離れた相手と、招待リンクでペアを作る。
enum PartnershipInvitation {
    enum Progress: Sendable {
        case waiting(URL)
        case paired(CKRecord.ID)
    }

    // MARK: 招待する側

    /// - Returns: 相手に送る招待リンク。
    static func send() async throws -> URL {
        let database = PartnershipShare.container.privateCloudDatabase
        // 前回のペアリングが途中で終わっていると、同じゾーンに共有が残っている。
        try await PartnershipShare.teardown(rootRecordID: PartnershipShare.ownedRootRecordID, isOwner: true)
        try await PartnershipShare.createZone(invitationRecordID.zoneID, in: database)

        let invitation = CKRecord(recordType: recordType, recordID: invitationRecordID)
        let share = CKShare(rootRecord: invitation)
        share[CKShare.SystemFieldKey.title] = PartnershipShare.title as CKRecordValue
        share.publicPermission = .readWrite
        return try await PartnershipShare.saveSharing(invitation, with: share, in: database)
    }

    /// 相手が招待リンクで参加していたら、その相手だけが参加できる共有をペアのルートレコードに作る。
    /// 相手がそちらにも参加していたら、招待リンクの共有を消してペアの成立を返す。
    static func advance(ownerRole: Role) async throws -> Progress {
        let database = PartnershipShare.container.privateCloudDatabase
        let rootRecordID = PartnershipShare.ownedRootRecordID
        if let root = try await PartnershipShare.fetchRoot(rootRecordID, from: database),
           let pairingShare = try await PartnershipShare.share(of: root, in: database) {
            if acceptedGuest(of: pairingShare) != nil {
                try await deleteInvitation(from: database)
                return .paired(rootRecordID)
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

    static func withdraw() async throws {
        try await PartnershipShare.teardown(rootRecordID: PartnershipShare.ownedRootRecordID, isOwner: true)
    }

    // MARK: 招待を受ける側

    /// - Returns: 招待のレコードの ID。
    static func join(_ metadata: CKShare.Metadata) async throws -> CKRecord.ID {
        try await PartnershipShare.accept(metadata)
        guard let invitationID = metadata.hierarchicalRootRecordID else {
            throw PartnershipShareError.metadataMissing
        }
        return invitationID
    }

    /// 招待した側が、こちらだけが参加できる共有を用意していたら参加する。
    /// - Returns: 参加できたペアのルートレコードの ID。まだ用意されていなければ nil。
    static func advanceJoining(_ invitationID: CKRecord.ID) async throws -> CKRecord.ID? {
        let database = PartnershipShare.container.sharedCloudDatabase
        guard let invitation = try await PartnershipShare.fetchRoot(invitationID, from: database) else {
            // 招待のレコードは、こちらがペアの共有に参加したのを見届けてから消される。
            let rootRecordID = CKRecord.ID(
                recordName: PartnershipShare.ownedRootRecordID.recordName,
                zoneID: invitationID.zoneID
            )
            guard try await PartnershipShare.fetchRoot(rootRecordID, from: database) != nil else {
                throw PartnershipShareError.invitationWithdrawn
            }
            return rootRecordID
        }
        guard let text = invitation[Key.pairingURL] as? String, let url = URL(string: text) else { return nil }
        return try await PartnershipShare.acceptShare(from: url)
    }

    static func leave(_ invitationID: CKRecord.ID) async throws {
        let database = PartnershipShare.container.sharedCloudDatabase
        guard let invitation = try await PartnershipShare.fetchRoot(invitationID, from: database),
              let shareID = invitation.share?.recordID else { return }
        let results = try await database.modifyRecords(saving: [], deleting: [shareID])
        try PartnershipShare.confirmDeleted(results.deleteResults[shareID])
    }
}

// MARK: - Private

private extension PartnershipInvitation {
    static let recordType = "Invitation"

    static var invitationRecordID: CKRecord.ID {
        CKRecord.ID(recordName: "invitation", zoneID: PartnershipShare.ownedRootRecordID.zoneID)
    }

    enum Key {
        static let pairingURL = "pairingURL"
    }

    static func acceptedGuest(of share: CKShare) -> CKShare.Participant? {
        share.participants.first { $0.role != .owner && $0.acceptanceStatus == .accepted }
    }

    static func fetchInvitation(from database: CKDatabase) async throws -> CKRecord {
        guard let invitation = try await PartnershipShare.fetchRoot(invitationRecordID, from: database) else {
            throw PartnershipShareError.invitationMissing
        }
        return invitation
    }

    static func url(of invitation: CKRecord, in database: CKDatabase) async throws -> URL {
        guard let url = try await PartnershipShare.shareURL(of: invitation, in: database) else {
            throw PartnershipShareError.shareURLUnavailable
        }
        return url
    }

    static func handOver(_ pairingURL: URL?, through invitation: CKRecord, in database: CKDatabase) async throws {
        guard let pairingURL else { throw PartnershipShareError.shareURLUnavailable }
        guard invitation[Key.pairingURL] as? String != pairingURL.absoluteString else { return }
        invitation[Key.pairingURL] = pairingURL.absoluteString as CKRecordValue
        _ = try await database.save(invitation)
    }

    static func deleteInvitation(from database: CKDatabase) async throws {
        guard let invitation = try await PartnershipShare.fetchRoot(invitationRecordID, from: database) else { return }
        let deleting = [invitation.share?.recordID, invitation.recordID].compactMap { $0 }
        let results = try await database.modifyRecords(saving: [], deleting: deleting)
        for id in deleting {
            try PartnershipShare.confirmDeleted(results.deleteResults[id])
        }
    }
}
