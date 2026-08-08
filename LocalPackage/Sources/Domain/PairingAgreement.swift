//
//  PairingAgreement.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

/// ペアの成立条件。2人がどちらのロールを取るかは、この2つの値だけで決まる。
public struct PairingAgreement: Sendable, Equatable {
    public let ownerRole: Role
    public let isOwner: Bool

    public init(ownerRole: Role, isOwner: Bool) {
        self.ownerRole = ownerRole
        self.isOwner = isOwner
    }

    /// 相手側ではなく、この端末が取るロール。
    public var role: Role {
        isOwner ? ownerRole : ownerRole.counterpart
    }
}
