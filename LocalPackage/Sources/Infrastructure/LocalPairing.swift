//
//  LocalPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain

/// 相手の端末を伴わずに成立させる。指定したロールを名乗り、自分がオーナーになる。
public struct LocalPairing: PartnershipPairing {
    public init() {}

    public func pair(as role: Role) async -> PairingAgreement {
        PairingAgreement(ownerRole: role, isOwner: true)
    }
}
