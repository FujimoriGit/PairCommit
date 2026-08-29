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
        let agreement = await pairing.pair(as: .owner(.player))

        // Then
        #expect(agreement.role == .player)
    }

    @Test("招待を受けた側は、相手が選ばなかったロールを名乗る")
    func joiningYieldsTheCounterpartRole() async {
        // Given
        let pairing = LocalPairing(ownerRole: .manager)

        // When
        let agreement = await pairing.pair(as: .participant)

        // Then
        #expect(agreement.role == .player)
    }

    @Test("成立したペアの取り決めは、そのままペアリングの確立に使える")
    func agreementEstablishesPairingInState() async throws {
        // Given
        let pairing = LocalPairing()
        let agreement = await pairing.pair(as: .owner(.manager))

        // When
        let state = try PartnershipState().establishingPairing(ownerRole: agreement.ownerRole)

        // Then
        #expect(state.pairing?.ownerRole == .manager)
    }
}
