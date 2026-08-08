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

    @Test("指定したロールで握手が成立し、その端末はそのロールを名乗る")
    func pairingLocallyYieldsTheRequestedRole() async {
        // Given
        let pairing = LocalPairing()

        // When
        let handshake = await pairing.pair(as: .player)

        // Then
        #expect(handshake.role == .player)
    }

    @Test("成立した握手はそのままペアリングの確立に使える")
    func handshakeEstablishesPairingInState() async throws {
        // Given
        let pairing = LocalPairing()
        let handshake = await pairing.pair(as: .manager)

        // When
        let state = try PartnershipState().establishingPairing(ownerRole: handshake.ownerRole)

        // Then
        #expect(state.pairing?.ownerRole == .manager)
    }
}
