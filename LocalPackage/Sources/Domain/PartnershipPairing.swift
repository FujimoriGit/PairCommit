//
//  PartnershipPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

public protocol PartnershipPairing: Sendable {
    /// 相手のロールは、指定したロールの対に決まる。
    func pair(as role: Role) async throws -> PairingAgreement
}
