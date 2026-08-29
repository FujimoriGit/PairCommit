//
//  PartnershipRootRecord.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/29
//

import CloudKit
import Domain
import Foundation

/// 共有ゾーンのルートレコードと PartnershipState の相互変換。
enum PartnershipRootRecord {
    static let type = "Pairing"

    static func decoding(_ record: CKRecord) -> PartnershipState? {
        guard let data = record[Key.state] as? Data else { return nil }
        return try? JSONDecoder().decode(PartnershipState.self, from: data)
    }

    static func encoding(_ state: PartnershipState, id: CKRecord.ID, base: CKRecord? = nil) -> CKRecord {
        let record = base ?? CKRecord(recordType: type, recordID: id)
        record[Key.state] = try? JSONEncoder().encode(state)
        return record
    }
}

// MARK: - Private

private extension PartnershipRootRecord {
    enum Key {
        static let state = "state"
    }
}
