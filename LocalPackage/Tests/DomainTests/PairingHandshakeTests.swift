//
//  PairingHandshakeTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain
import Testing

struct PairingHandshakeTests {

    @Test("オーナー側の自ロールは、オーナーが選んだロールそのもの")
    func ownerTakesTheRoleItChose() {
        // Given
        let handshake = PairingHandshake(ownerRole: .manager, isOwner: true)

        // When / Then
        #expect(handshake.role == .manager)
    }

    @Test("参加者側の自ロールは、オーナーが選ばなかった方に決まる")
    func participantTakesTheRemainingRole() {
        // Given
        let handshake = PairingHandshake(ownerRole: .manager, isOwner: false)

        // When / Then
        #expect(handshake.role == .player)
    }

    @Test("ペアの2人は必ず異なるロールを持つ")
    func theTwoSidesNeverShareARole() {
        for ownerRole in Role.allCases {
            // Given
            let owner = PairingHandshake(ownerRole: ownerRole, isOwner: true)
            let participant = PairingHandshake(ownerRole: ownerRole, isOwner: false)

            // When / Then
            #expect(owner.role != participant.role)
        }
    }
}
