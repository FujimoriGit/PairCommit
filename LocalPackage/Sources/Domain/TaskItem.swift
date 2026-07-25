//
//  TaskItem.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

// 型名が `TaskItem` なのは Swift Concurrency の `Task` との衝突を避けるため。
public struct TaskItem: Identifiable, Sendable, Codable, Equatable {
    public enum Status: String, Sendable, Codable {
        case proposed
        case todo
        case reported
        case approved
        case cancelled

        public var isOpen: Bool {
            switch self {
            case .proposed, .todo, .reported: return true
            case .approved, .cancelled:       return false
            }
        }
    }

    public let id: UUID
    public let visionID: Vision.ID
    public let title: String
    public let status: Status
    public let createdBy: Role
    public let reaction: Reaction?
    public let deadline: Date?
    public let createdAt: Date

    public init(
        id: UUID,
        visionID: Vision.ID,
        title: String,
        status: Status,
        createdBy: Role,
        reaction: Reaction?,
        deadline: Date?,
        createdAt: Date
    ) {
        self.id = id
        self.visionID = visionID
        self.title = title
        self.status = status
        self.createdBy = createdBy
        self.reaction = reaction
        self.deadline = deadline
        self.createdAt = createdAt
    }

    func with(status: Status) -> Self {
        with(status: status, reaction: reaction)
    }

    func with(reaction: Reaction?) -> Self {
        with(status: status, reaction: reaction)
    }
}

// MARK: - Private

private extension TaskItem {
    func with(status: Status, reaction: Reaction?) -> Self {
        .init(
            id: id,
            visionID: visionID,
            title: title,
            status: status,
            createdBy: createdBy,
            reaction: reaction,
            deadline: deadline,
            createdAt: createdAt
        )
    }
}
