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
        let state = try JSONDecoder().decode(PartnershipState.self, from: data)
        return .init(
            pairing: state.pairing.map {
                naming($0, manager: record[Key.managerName] as? String, player: record[Key.playerName] as? String)
            },
            visions: state.visions,
            tasks: state.tasks
        )
    }

    static func creating(_ state: PartnershipState, id: CKRecord.ID) throws -> CKRecord {
        try encoding(state, into: CKRecord(recordType: type, recordID: id))
    }

    // 名前を知らない版のアプリは state を丸ごと書き戻すので、名前は state の外に置く
    static func encoding(_ state: PartnershipState, into record: CKRecord) throws -> CKRecord {
        let unnamed = PartnershipState(
            pairing: state.pairing.map { naming($0, manager: nil, player: nil) },
            visions: state.visions,
            tasks: state.tasks
        )
        record[Key.state] = try JSONEncoder().encode(unnamed)
        record[Key.managerName] = state.pairing?.managerName
        record[Key.playerName] = state.pairing?.playerName
        return record
    }
}

// MARK: - Private

private extension PartnershipRootRecord {
    enum Key {
        static let state = "state"
        static let managerName = "managerName"
        static let playerName = "playerName"
    }

    enum Failure: Error {
        case stateMissing
    }

    static func naming(_ pairing: Pairing, manager: String?, player: String?) -> Pairing {
        .init(
            id: pairing.id,
            ownerRole: pairing.ownerRole,
            createdAt: pairing.createdAt,
            managerName: manager,
            playerName: player
        )
    }
}
