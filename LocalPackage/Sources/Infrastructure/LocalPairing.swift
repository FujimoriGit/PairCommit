//
//  LocalPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain

/// 相手の端末を必要とせず、指定したロールで即座に成立する握手。
public struct LocalPairing: PartnershipPairing {
    public init() {}

    public func pair(as role: Role) async -> PairingHandshake {
        PairingHandshake(ownerRole: role, isOwner: true)
    }
}
