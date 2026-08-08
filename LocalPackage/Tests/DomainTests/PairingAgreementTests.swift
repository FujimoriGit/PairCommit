//
//  PairingAgreementTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain
import Testing

struct PairingAgreementTests {

    @Test("オーナー側の自ロールは、オーナーが選んだロールそのもの")
    func ownerTakesTheRoleItChose() {
        // Given
        let agreement = PairingAgreement(ownerRole: .manager, isOwner: true)

        // When / Then
        #expect(agreement.role == .manager)
    }

    @Test("参加者側の自ロールは、オーナーが選ばなかった方に決まる")
    func participantTakesTheRemainingRole() {
        // Given
        let agreement = PairingAgreement(ownerRole: .manager, isOwner: false)

        // When / Then
        #expect(agreement.role == .player)
    }

    @Test("ペアの2人は必ず異なるロールを持つ")
    func theTwoSidesNeverShareARole() {
        for ownerRole in Role.allCases {
            // Given
            let owner = PairingAgreement(ownerRole: ownerRole, isOwner: true)
            let participant = PairingAgreement(ownerRole: ownerRole, isOwner: false)

            // When / Then
            #expect(owner.role != participant.role)
        }
    }
}
