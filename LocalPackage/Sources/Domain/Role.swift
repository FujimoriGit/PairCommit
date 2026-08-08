//
//  Role.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

public enum Role: String, Sendable, Codable, CaseIterable {
    case manager
    case player

    public var counterpart: Self {
        switch self {
        case .manager: .player
        case .player: .manager
        }
    }
}
