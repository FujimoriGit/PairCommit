//
//  PairingFailure.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Domain

/// ペアリングとペアの終了が失敗した理由を、利用者が自分で手を打てる単位に分けたもの。
public enum PairingFailure: Error, Equatable, Sendable {
    case signedOut
    case accountUnverified
    case storageFull
    case serverBusy
    case offline
    case nearbyUnavailable
    case disconnected
    case partnerFailed
    case sameRole(Role)
    case bothAccepting
    case unexpected
}
