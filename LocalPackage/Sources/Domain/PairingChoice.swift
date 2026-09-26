//
//  PairingChoice.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

/// ペアリングの最初の画面で選んだもの。役割か、相手の招待を受けるか。
public enum PairingChoice: Equatable, Sendable {
    case role(Role)
    case invitation

    public func plan(with partner: Self) -> PairingPlan {
        switch (self, partner) {
        case (.role(let role), .invitation):
            .makeShare(ownerRole: role)
        case (.invitation, .role):
            .awaitShare
        case (.invitation, .invitation):
            .bothAccepting
        case (.role(let role), .role(let partnerRole)):
            if role == partnerRole {
                .sameRole(role)
            } else if role == .manager {
                .makeShare(ownerRole: role)
            } else {
                .awaitShare
            }
        }
    }
}

public enum PairingPlan: Equatable, Sendable {
    case makeShare(ownerRole: Role)
    case awaitShare
    case sameRole(Role)
    case bothAccepting
}
