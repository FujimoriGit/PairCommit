//
//  PartnershipRootRecord.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/29
//

import CloudKit
import Domain
import Foundation

enum PartnershipRootRecord {
    static let type = "Pairing"

    static func decoding(_ record: CKRecord) throws -> PartnershipState {
        guard let data = record[Key.state] as? Data else { throw Failure.stateMissing }
        return try JSONDecoder().decode(PartnershipState.self, from: data)
    }

    static func creating(_ state: PartnershipState, id: CKRecord.ID) throws -> CKRecord {
        try encoding(state, into: CKRecord(recordType: type, recordID: id))
    }

    static func encoding(_ state: PartnershipState, into record: CKRecord) throws -> CKRecord {
        record[Key.state] = try JSONEncoder().encode(state)
        return record
    }
}

// MARK: - Private

private extension PartnershipRootRecord {
    enum Key {
        static let state = "state"
    }

    enum Failure: Error {
        case stateMissing
    }
}
