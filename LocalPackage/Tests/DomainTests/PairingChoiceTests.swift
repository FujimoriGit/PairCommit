//
//  PairingChoiceTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import Testing

struct PairingChoiceTests {

    @Test("役割と招待を1台ずつ選ぶと、役割を選んだ端末がその役割で共有を作り、招待を選んだ端末は受ける")
    func roleAndInvitationPairWithTheChosenRole() {
        for role in Role.allCases {
            // Given
            let chooser = PairingChoice.role(role)
            let invitee = PairingChoice.invitation

            // When / Then
            #expect(chooser.plan(with: invitee) == .makeShare(ownerRole: role))
            #expect(invitee.plan(with: chooser) == .awaitShare)
        }
    }

    @Test("違う役割を1台ずつ選ぶと、見届ける人の端末が共有を作り、挑む人の端末は受ける")
    func differentRolesPairWithTheManagerMakingTheShare() {
        // Given
        let manager = PairingChoice.role(.manager)
        let player = PairingChoice.role(.player)

        // When / Then
        #expect(manager.plan(with: player) == .makeShare(ownerRole: .manager))
        #expect(player.plan(with: manager) == .awaitShare)
    }

    @Test("2台とも同じ役割を選ぶと、どちらも共有を作らずに止まる")
    func sameRoleStopsBothSides() {
        for role in Role.allCases {
            // Given
            let choice = PairingChoice.role(role)

            // When / Then
            #expect(choice.plan(with: choice) == .sameRole(role))
        }
    }

    @Test("2台とも招待を受けるを選ぶと、どちらも共有を作らずに止まる")
    func bothInvitationsStopBothSides() {
        // Given
        let choice = PairingChoice.invitation

        // When / Then
        #expect(choice.plan(with: choice) == .bothAccepting)
    }
}
