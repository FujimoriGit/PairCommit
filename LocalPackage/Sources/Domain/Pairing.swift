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

    public init(id: UUID, ownerRole: Role, createdAt: Date) {
        self.id = id
        self.ownerRole = ownerRole
        self.createdAt = createdAt
    }
}
