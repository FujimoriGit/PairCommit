//
//  PairingAgreementTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain
import Testing

struct PairingAgreementTests {

    @Test("共有を作った側の役割は、その人が選んだ役割になる")
    func ownerTakesTheRoleItChose() {
        // Given
        let agreement = PairingAgreement(ownerRole: .manager, isOwner: true)

        // When / Then
        #expect(agreement.role == .manager)
    }

    @Test("共有に参加した側の役割は、作った側が選ばなかった方になる")
    func participantTakesTheRemainingRole() {
        // Given
        let agreement = PairingAgreement(ownerRole: .manager, isOwner: false)

        // When / Then
        #expect(agreement.role == .player)
    }

    @Test("ペアの2人が同じ役割になることはない", arguments: Role.allCases)
    func theTwoSidesNeverShareARole(ownerRole: Role) {
        // Given
        let owner = PairingAgreement(ownerRole: ownerRole, isOwner: true)
        let participant = PairingAgreement(ownerRole: ownerRole, isOwner: false)

        // When / Then
        #expect(owner.role != participant.role)
    }
}
