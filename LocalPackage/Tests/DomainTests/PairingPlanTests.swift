//
//  PairingPlanTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/06
//

import Domain
import Testing

struct PairingPlanTests {

    @Test("違う役割を1台ずつ選ぶと、見届ける人の端末が共有を作り、挑む人の端末は受ける")
    func differentRolesPairWithTheManagerMakingTheShare() {
        // When / Then
        #expect(PairingPlan(role: .manager, partnerRole: .player) == .makeShare(ownerRole: .manager))
        #expect(PairingPlan(role: .player, partnerRole: .manager) == .awaitShare)
    }

    @Test("2台とも同じ役割を選ぶと、どちらも共有を作らずに止まる")
    func sameRoleStopsBothSides() {
        for role in Role.allCases {
            // When / Then
            #expect(PairingPlan(role: role, partnerRole: role) == .sameRole(role))
        }
    }
}
