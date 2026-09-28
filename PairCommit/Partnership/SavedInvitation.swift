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
        guard defaults.bool(forKey: withdrawingKey) else { return nil }
        guard
            let recordName = defaults.string(forKey: pairRecordNameKey),
            let zoneName = defaults.string(forKey: pairZoneNameKey),
            let ownerName = defaults.string(forKey: pairOwnerNameKey)
        else { return .invitation }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        return .pair(.init(
            rootRecordID: CKRecord.ID(recordName: recordName, zoneID: zoneID),
            isOwner: defaults.bool(forKey: pairIsOwnerKey)
        ))
    }

    static func save(_ withdrawal: Withdrawal) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: withdrawingKey)
        if case .pair(let paired) = withdrawal {
            defaults.set(paired.rootRecordID.recordName, forKey: pairRecordNameKey)
            defaults.set(paired.rootRecordID.zoneID.zoneName, forKey: pairZoneNameKey)
            defaults.set(paired.rootRecordID.zoneID.ownerName, forKey: pairOwnerNameKey)
            defaults.set(paired.isOwner, forKey: pairIsOwnerKey)
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
            withdrawingKey, pairRecordNameKey, pairZoneNameKey, pairOwnerNameKey, pairIsOwnerKey
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
    static let withdrawingKey = "invitation.withdrawing"
    static let pairRecordNameKey = "invitation.pair.recordName"
    static let pairZoneNameKey = "invitation.pair.zoneName"
    static let pairOwnerNameKey = "invitation.pair.ownerName"
    static let pairIsOwnerKey = "invitation.pair.isOwner"
}
