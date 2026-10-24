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

extension SyncFailure: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unavailable: "unavailable"
        case .outdated: "outdated"
        }
    }
}
