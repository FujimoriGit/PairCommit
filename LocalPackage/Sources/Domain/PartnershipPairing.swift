//
//  PartnershipPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

public protocol PartnershipPairing: Sendable {
    func pair(as side: PairingSide) async throws -> PairingAgreement
}
