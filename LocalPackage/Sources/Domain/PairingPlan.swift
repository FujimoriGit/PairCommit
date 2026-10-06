//
//  PairingPlan.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/06
//

/// 近くの相手とつながったあと、2台が選んだ役割から決まる、この端末の動き。
public enum PairingPlan: Equatable, Sendable {
    case makeShare(ownerRole: Role)
    case awaitShare
    case sameRole(Role)

    public init(role: Role, partnerRole: Role) {
        if role == partnerRole {
            self = .sameRole(role)
        } else if role == .manager {
            self = .makeShare(ownerRole: role)
        } else {
            self = .awaitShare
        }
    }
}
