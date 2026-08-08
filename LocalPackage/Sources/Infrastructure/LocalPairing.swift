//
//  LocalPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain

public struct LocalPairing: PartnershipPairing {
    public init() {}

    public func pair(as role: Role) async -> PairingAgreement {
        PairingAgreement(ownerRole: role, isOwner: true)
    }
}
