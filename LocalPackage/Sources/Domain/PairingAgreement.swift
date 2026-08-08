//
//  PairingAgreement.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

public struct PairingAgreement: Sendable, Equatable {
    public let ownerRole: Role
    public let isOwner: Bool

    public init(ownerRole: Role, isOwner: Bool) {
        self.ownerRole = ownerRole
        self.isOwner = isOwner
    }

    public var role: Role {
        isOwner ? ownerRole : ownerRole.counterpart
    }
}
