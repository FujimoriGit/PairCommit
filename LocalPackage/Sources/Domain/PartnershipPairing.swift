//
//  PartnershipPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

/// 2人が同じペアであることを確定させる握手。
public protocol PartnershipPairing: Sendable {
    /// 自分が取るロールを指定して握手する。相手のロールはその対と決まる。
    func pair(as role: Role) async throws -> PairingHandshake
}

/// 握手の結果。ここから `Pairing` と各端末の自ロールが定まる。
public struct PairingHandshake: Sendable, Equatable {
    public let ownerRole: Role
    public let isOwner: Bool

    public init(ownerRole: Role, isOwner: Bool) {
        self.ownerRole = ownerRole
        self.isOwner = isOwner
    }

    /// 握手した端末自身のロール。
    public var role: Role {
        isOwner ? ownerRole : ownerRole.counterpart
    }
}
