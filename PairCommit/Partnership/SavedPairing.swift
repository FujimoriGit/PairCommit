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
            let data = defaults.data(forKey: rootRecordIDKey),
            let rootRecordID = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.ID.self, from: data)
        else { return nil }
        return .init(rootRecordID: rootRecordID, isOwner: defaults.bool(forKey: isOwnerKey))
    }

    static func save(_ outcome: MultipeerPairing.Outcome) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: outcome.rootRecordID, requiringSecureCoding: true)
        UserDefaults.standard.set(data, forKey: rootRecordIDKey)
        UserDefaults.standard.set(outcome.isOwner, forKey: isOwnerKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: rootRecordIDKey)
        UserDefaults.standard.removeObject(forKey: isOwnerKey)
    }
}

// MARK: - Private

private extension SavedPairing {
    static let rootRecordIDKey = "pairing.rootRecordID"
    static let isOwnerKey = "pairing.isOwner"
}
