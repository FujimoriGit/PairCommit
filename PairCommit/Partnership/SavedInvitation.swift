//
//  SavedInvitation.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import Foundation

/// 離れた相手とのペアリングの途中を端末に残す。開き直しても、相手を待っていたところに戻る。
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
        return .joined(invitationID: .init(recordName: recordName, zoneName: zoneName, zoneOwnerName: ownerName))
    }

    static func save(_ step: InvitationStep) {
        clear()
        let defaults = UserDefaults.standard
        switch step {
        case .sent(let role):
            defaults.set(role.rawValue, forKey: ownerRoleKey)
        case .joined(let invitationID):
            defaults.set(invitationID.recordName, forKey: recordNameKey)
            defaults.set(invitationID.zoneName, forKey: zoneNameKey)
            defaults.set(invitationID.zoneOwnerName, forKey: ownerNameKey)
        case .sending, .accepting:
            break
        }
    }

    static func clear() {
        for key in [ownerRoleKey, recordNameKey, zoneNameKey, ownerNameKey] {
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
}
