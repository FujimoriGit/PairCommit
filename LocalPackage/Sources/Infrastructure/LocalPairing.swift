//
//  LocalPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain

// 単一端末で動かすための仮実装。招待を受ける側が本来は相手から受け取る
// オーナーのロールを、ここでは初期化時に渡してもらう。
public struct LocalPairing: PartnershipPairing {
    private let ownerRole: Role

    public init(ownerRole: Role = .manager) {
        self.ownerRole = ownerRole
    }

    public func pair(as side: PairingSide) async -> PairingAgreement {
        switch side {
        case .owner(let role): PairingAgreement(ownerRole: role, isOwner: true)
        case .participant: PairingAgreement(ownerRole: ownerRole, isOwner: false)
        }
    }
}
