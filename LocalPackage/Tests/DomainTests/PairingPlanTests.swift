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
        // Given
        let manager = Role.manager
        let player = Role.player

        // When
        let managerPlan = PairingPlan(role: manager, partnerRole: player)
        let playerPlan = PairingPlan(role: player, partnerRole: manager)

        // Then
        #expect(managerPlan == .makeShare(ownerRole: .manager))
        #expect(playerPlan == .awaitShare)
    }

    @Test("2台とも同じ役割を選ぶと、どちらの端末も共有を作らずに、選んだ役割が重なったことを伝えて止まる", arguments: Role.allCases)
    func sameRoleStopsBothSides(chosen: Role) {
        // Given
        let myRole = chosen
        let partnerRole = chosen

        // When
        let plan = PairingPlan(role: myRole, partnerRole: partnerRole)

        // Then
        #expect(plan == .sameRole(chosen))
    }
}
