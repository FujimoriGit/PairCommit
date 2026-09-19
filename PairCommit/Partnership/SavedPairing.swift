//
//  SavedPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/19
//

import CloudKit
import Foundation

/// 成立したペアリングの結果を端末に残す。起動し直しても、役割の選択からやり直さずに済む。
enum SavedPairing {
    static func load() -> MultipeerPairing.Outcome? {
        let defaults = UserDefaults.standard
        guard
            let recordName = defaults.string(forKey: recordNameKey),
            let zoneName = defaults.string(forKey: zoneNameKey),
            let ownerName = defaults.string(forKey: ownerNameKey)
        else { return nil }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        return .init(
            rootRecordID: CKRecord.ID(recordName: recordName, zoneID: zoneID),
            isOwner: defaults.bool(forKey: isOwnerKey)
        )
    }

    static func save(_ outcome: MultipeerPairing.Outcome) {
        let defaults = UserDefaults.standard
        defaults.set(outcome.rootRecordID.recordName, forKey: recordNameKey)
        defaults.set(outcome.rootRecordID.zoneID.zoneName, forKey: zoneNameKey)
        defaults.set(outcome.rootRecordID.zoneID.ownerName, forKey: ownerNameKey)
        defaults.set(outcome.isOwner, forKey: isOwnerKey)
    }

    static func clear() {
        for key in [recordNameKey, zoneNameKey, ownerNameKey, isOwnerKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - Private

private extension SavedPairing {
    static let recordNameKey = "pairing.recordName"
    static let zoneNameKey = "pairing.zoneName"
    static let ownerNameKey = "pairing.ownerName"
    static let isOwnerKey = "pairing.isOwner"
}
