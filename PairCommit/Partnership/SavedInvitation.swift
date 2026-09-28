//
//  SavedInvitation.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import CloudKit
import Domain
import Foundation

/// 離れた相手とのペアリングの途中を端末に残す。開き直しても、相手を待っていたところか、やめる後始末の途中に戻る。
enum SavedInvitation {
    static func load() -> InvitationStep? {
        let defaults = UserDefaults.standard
        if let role = defaults.string(forKey: ownerRoleKey).flatMap(Role.init(rawValue:)) {
            return .sent(ownerRole: role)
        }
        guard
            let recordName = defaults.string(forKey: recordNameKey),
            let zoneName = defaults.string(forKey: zoneNameKey),
            let ownerName = defaults.string(forKey: ownerNameKey)
        else { return nil }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        return .joined(invitationID: CKRecord.ID(recordName: recordName, zoneID: zoneID))
    }

    static func loadWithdrawal() -> Withdrawal? {
        let defaults = UserDefaults.standard
        let recordID = defaults.string(forKey: withdrawalRecordNameKey).flatMap { recordName -> CKRecord.ID? in
            guard
                let zoneName = defaults.string(forKey: withdrawalZoneNameKey),
                let ownerName = defaults.string(forKey: withdrawalOwnerNameKey)
            else { return nil }
            return CKRecord.ID(recordName: recordName, zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName))
        }
        switch (defaults.string(forKey: withdrawalKindKey), recordID) {
        case ("invitation"?, _):
            return .invitation
        case ("membership"?, let invitationID?):
            return .membership(invitationID: invitationID)
        case ("pair"?, let rootRecordID?):
            return .pair(.init(rootRecordID: rootRecordID, isOwner: defaults.bool(forKey: withdrawalIsOwnerKey)))
        default:
            return nil
        }
    }

    static func save(_ withdrawal: Withdrawal) {
        let defaults = UserDefaults.standard
        let recordID: CKRecord.ID?
        switch withdrawal {
        case .invitation:
            defaults.set("invitation", forKey: withdrawalKindKey)
            recordID = nil
        case .membership(let invitationID):
            defaults.set("membership", forKey: withdrawalKindKey)
            recordID = invitationID
        case .pair(let paired):
            defaults.set("pair", forKey: withdrawalKindKey)
            defaults.set(paired.isOwner, forKey: withdrawalIsOwnerKey)
            recordID = paired.rootRecordID
        }
        if let recordID {
            defaults.set(recordID.recordName, forKey: withdrawalRecordNameKey)
            defaults.set(recordID.zoneID.zoneName, forKey: withdrawalZoneNameKey)
            defaults.set(recordID.zoneID.ownerName, forKey: withdrawalOwnerNameKey)
        }
    }

    static func save(_ step: InvitationStep) {
        clear()
        let defaults = UserDefaults.standard
        switch step {
        case .sent(let role):
            defaults.set(role.rawValue, forKey: ownerRoleKey)
        case .joined(let invitationID):
            defaults.set(invitationID.recordName, forKey: recordNameKey)
            defaults.set(invitationID.zoneID.zoneName, forKey: zoneNameKey)
            defaults.set(invitationID.zoneID.ownerName, forKey: ownerNameKey)
        case .sending, .accepting:
            break
        }
    }

    static func clear() {
        let keys = [
            ownerRoleKey, recordNameKey, zoneNameKey, ownerNameKey,
            withdrawalKindKey, withdrawalRecordNameKey, withdrawalZoneNameKey, withdrawalOwnerNameKey, withdrawalIsOwnerKey
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - Private

private extension SavedInvitation {
    static let ownerRoleKey = "invitation.ownerRole"
    static let recordNameKey = "invitation.recordName"
    static let zoneNameKey = "invitation.zoneName"
    static let ownerNameKey = "invitation.ownerName"
    static let withdrawalKindKey = "invitation.withdrawal.kind"
    static let withdrawalRecordNameKey = "invitation.withdrawal.recordName"
    static let withdrawalZoneNameKey = "invitation.withdrawal.zoneName"
    static let withdrawalOwnerNameKey = "invitation.withdrawal.ownerName"
    static let withdrawalIsOwnerKey = "invitation.withdrawal.isOwner"
}
