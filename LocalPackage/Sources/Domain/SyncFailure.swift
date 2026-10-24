//
//  SyncFailure.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

public enum SyncFailure: Error, Equatable, Sendable {
    case unavailable
    case outdated(latest: PartnershipState)
}

// 失敗を書き出すときに、利用者が書いた文を含む状態まで書き出さない。
extension SyncFailure: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unavailable: "unavailable"
        case .outdated: "outdated"
        }
    }
}
