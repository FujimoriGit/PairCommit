//
//  Pairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

public struct Pairing: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let ownerRole: Role
    public let createdAt: Date
    public let managerName: String?
    public let playerName: String?

    public init(id: UUID, ownerRole: Role, createdAt: Date, managerName: String? = nil, playerName: String? = nil) {
        self.id = id
        self.ownerRole = ownerRole
        self.createdAt = createdAt
        self.managerName = managerName
        self.playerName = playerName
    }

    public func name(of role: Role) -> String? {
        switch role {
        case .manager: managerName
        case .player: playerName
        }
    }
}

extension Pairing {
    func naming(_ role: Role, as name: String) -> Self {
        .init(
            id: id,
            ownerRole: ownerRole,
            createdAt: createdAt,
            managerName: role == .manager ? name : managerName,
            playerName: role == .player ? name : playerName
        )
    }
}
