//
//  PartnershipNamingTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import Foundation
import Testing

struct PartnershipNamingTests {
    @Test("自分の名前を決めると、相手の名前は変わらない")
    func namingChangesOnlyTheNamersOwnName() throws {
        // Given
        let state = try PartnershipState()
            .establishingPairing(ownerRole: .manager)
            .naming("花子", by: .player)

        // When
        let named = try state.naming("太郎", by: .manager)

        // Then
        #expect(named.pairing?.name(of: .manager) == "太郎")
        #expect(named.pairing?.name(of: .player) == "花子")
    }

    @Test("名前は前後の空白を落として持ち、空白だけにはできない")
    func nameIsTrimmedAndCannotBeBlank() throws {
        // Given
        let state = try PartnershipState().establishingPairing(ownerRole: .manager)

        // When
        let named = try state.naming("  太郎\n", by: .manager)

        // Then
        #expect(named.pairing?.name(of: .manager) == "太郎")
        #expect(throws: DomainError.blankText) {
            try state.naming(" \n", by: .manager)
        }
    }

    @Test("ペアが無ければ名前は決められない")
    func namingWithoutPairFails() {
        #expect(throws: DomainError.notPaired) {
            try PartnershipState().naming("太郎", by: .manager)
        }
    }

    @Test("名前が入る前に保存したペアも読み込め、名前は未定になる")
    func pairSavedBeforeNamesExistedDecodesWithoutNames() throws {
        // Given
        let saved = Data("""
            {"pairing":{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","ownerRole":"manager","createdAt":0},"visions":[],"tasks":[]}
            """.utf8)

        // When
        let state = try JSONDecoder().decode(PartnershipState.self, from: saved)

        // Then
        #expect(state.pairing?.ownerRole == .manager)
        #expect(state.pairing?.name(of: .manager) == nil)
        #expect(state.pairing?.name(of: .player) == nil)
    }
}
