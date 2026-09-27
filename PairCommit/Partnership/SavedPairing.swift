//
//  SavedPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/19
//

import Foundation

/// 成立したペアリングの結果を端末に残す。起動し直しても、役割の選択からやり直さずに済む。
enum SavedPairing {
    static func load() -> PairingOutcome? {
        let defaults = UserDefaults.standard
        guard
            let recordName = defaults.string(forKey: recordNameKey),
            let zoneName = defaults.string(forKey: zoneNameKey),
            let ownerName = defaults.string(forKey: ownerNameKey)
        else { return nil }
        return .init(
            rootRecordID: .init(recordName: recordName, zoneName: zoneName, zoneOwnerName: ownerName),
            isOwner: defaults.bool(forKey: isOwnerKey)
        )
    }

    static func save(_ outcome: PairingOutcome) {
        let defaults = UserDefaults.standard
        defaults.set(outcome.rootRecordID.recordName, forKey: recordNameKey)
        defaults.set(outcome.rootRecordID.zoneName, forKey: zoneNameKey)
        defaults.set(outcome.rootRecordID.zoneOwnerName, forKey: ownerNameKey)
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
