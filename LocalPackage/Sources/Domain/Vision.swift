//
//  Vision.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

public struct Vision: Identifiable, Sendable, Codable, Equatable {
    public enum Status: String, Sendable, Codable {
        case draft
        case proposed
        case active
        case achieved
        case abandoned
    }

    public enum Outcome: String, Sendable, Codable, CaseIterable {
        case achieved
        case abandoned

        public var status: Status {
            switch self {
            case .achieved:  return .achieved
            case .abandoned: return .abandoned
            }
        }
    }

    public let id: UUID
    public let statement: String
    public let doneCriteria: String
    public let deadline: Date?
    public let why: String?
    public let status: Status
    public let createdAt: Date

    public init(
        id: UUID,
        statement: String,
        doneCriteria: String,
        deadline: Date?,
        why: String?,
        status: Status,
        createdAt: Date
    ) {
        self.id = id
        self.statement = statement
        self.doneCriteria = doneCriteria
        self.deadline = deadline
        self.why = why
        self.status = status
        self.createdAt = createdAt
    }

    func with(status: Status) -> Self {
        .init(
            id: id,
            statement: statement,
            doneCriteria: doneCriteria,
            deadline: deadline,
            why: why,
            status: status,
            createdAt: createdAt
        )
    }
}
