//
//  SavedInvitation.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Application
import CloudKit
import Domain
import Foundation

/// 離れた相手とのペアリングの途中を端末に残す。開き直しても、相手を待っていたところか、やめる後始末の途中に戻る。
enum SavedInvitation {
    static func loadStep() -> InvitationStep? {
        let defaults = UserDefaults.standard
        if let role = defaults.string(forKey: ownerRoleKey).flatMap(Role.init(rawValue:)) {
            return .sent(ownerRole: role)
        }
        guard defaults.bool(forKey: joinedKey), joinedInvitationID() != nil else { return nil }
        return .joined
    }

    static func loadWithdrawal() -> Withdrawal? {
        UserDefaults.standard.string(forKey: withdrawalKey).flatMap(Kind.init(rawValue:))?.withdrawal
    }

    static func save(_ step: InvitationStep) {
        let defaults = UserDefaults.standard
        for key in [ownerRoleKey, joinedKey, withdrawalKey] {
            defaults.removeObject(forKey: key)
        }
        switch step {
        case .sent(let role):
            defaults.set(role.rawValue, forKey: ownerRoleKey)
        case .joined:
            defaults.set(true, forKey: joinedKey)
        case .sending, .accepting:
            break
        }
    }

    static func save(_ withdrawal: Withdrawal) {
        UserDefaults.standard.set(Kind(withdrawal).rawValue, forKey: withdrawalKey)
    }

    /// 参加した招待のレコードの ID。
    static func joinedInvitationID() -> CKRecord.ID? {
        let defaults = UserDefaults.standard
        guard
            let recordName = defaults.string(forKey: recordNameKey),
            let zoneName = defaults.string(forKey: zoneNameKey),
            let ownerName = defaults.string(forKey: ownerNameKey)
        else { return nil }
        return CKRecord.ID(recordName: recordName, zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName))
    }

    static func saveJoinedInvitationID(_ invitationID: CKRecord.ID) {
        let defaults = UserDefaults.standard
        defaults.set(invitationID.recordName, forKey: recordNameKey)
        defaults.set(invitationID.zoneID.zoneName, forKey: zoneNameKey)
        defaults.set(invitationID.zoneID.ownerName, forKey: ownerNameKey)
    }

    static func clear() {
        for key in [ownerRoleKey, joinedKey, withdrawalKey, recordNameKey, zoneNameKey, ownerNameKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - Private

private extension SavedInvitation {
    enum Kind: String {
        case invitation
        case membership
        case pair

        init(_ withdrawal: Withdrawal) {
            switch withdrawal {
            case .invitation: self = .invitation
            case .membership: self = .membership
            case .pair: self = .pair
            }
        }

        var withdrawal: Withdrawal {
            switch self {
            case .invitation: .invitation
            case .membership: .membership
            case .pair: .pair
            }
        }
    }

    static let ownerRoleKey = "invitation.ownerRole"
    static let joinedKey = "invitation.joined"
    static let withdrawalKey = "invitation.withdrawal.kind"
    static let recordNameKey = "invitation.recordName"
    static let zoneNameKey = "invitation.zoneName"
    static let ownerNameKey = "invitation.ownerName"
}
