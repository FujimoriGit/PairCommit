//
//  LocalPairingTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain
import Infrastructure
import Testing

struct LocalPairingTests {

    @Test("指定したロールでペアが成立し、その端末はそのロールを名乗る")
    func pairingLocallyYieldsTheRequestedRole() async {
        // Given
        let pairing = LocalPairing()

        // When
        let agreement = await pairing.pair(as: .player)

        // Then
        #expect(agreement.role == .player)
    }

    @Test("成立したペアの取り決めは、そのままペアリングの確立に使える")
    func agreementEstablishesPairingInState() async throws {
        // Given
        let pairing = LocalPairing()
        let agreement = await pairing.pair(as: .manager)

        // When
        let state = try PartnershipState().establishingPairing(ownerRole: agreement.ownerRole)

        // Then
        #expect(state.pairing?.ownerRole == .manager)
    }
}
