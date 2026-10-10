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
    public let detail: String?
    public let status: Status
    public let createdBy: Role
    public let reaction: Reaction?
    public let deadline: Date?
    public let createdAt: Date
    public let statusChangedAt: Date
    /// 取り消したタスクの、取り消す前の状態。取り消していないときと、分からないときは nil。
    public let cancelledFrom: Status?
    /// 見届ける人が決めた進捗率（0〜100）。決めていないときは nil。
    public let progress: Int?

    public init(
        id: UUID,
        visionID: Vision.ID,
        title: String,
        detail: String?,
        status: Status,
        createdBy: Role,
        reaction: Reaction?,
        deadline: Date?,
        createdAt: Date,
        statusChangedAt: Date,
        cancelledFrom: Status? = nil,
        progress: Int? = nil
    ) {
        self.id = id
        self.visionID = visionID
        self.title = title
        self.detail = detail
        self.status = status
        self.createdBy = createdBy
        self.reaction = reaction
        self.deadline = deadline
        self.createdAt = createdAt
        self.statusChangedAt = statusChangedAt
        self.cancelledFrom = cancelledFrom
        self.progress = progress
    }

    func with(status: Status, at changedAt: Date) -> Self {
        with(
            status: status,
            reaction: reaction,
            statusChangedAt: changedAt,
            cancelledFrom: status == .cancelled ? self.status : nil,
            progress: progress
        )
    }

    func with(reaction: Reaction?) -> Self {
        with(
            status: status,
            reaction: reaction,
            statusChangedAt: statusChangedAt,
            cancelledFrom: cancelledFrom,
            progress: progress
        )
    }

    func with(progress: Int) -> Self {
        with(
            status: status,
            reaction: reaction,
            statusChangedAt: statusChangedAt,
            cancelledFrom: cancelledFrom,
            progress: progress
        )
    }
}

// MARK: - Private

private extension TaskItem {
    func with(
        status: Status,
        reaction: Reaction?,
        statusChangedAt: Date,
        cancelledFrom: Status?,
        progress: Int?
    ) -> Self {
        .init(
            id: id,
            visionID: visionID,
            title: title,
            detail: detail,
            status: status,
            createdBy: createdBy,
            reaction: reaction,
            deadline: deadline,
            createdAt: createdAt,
            statusChangedAt: statusChangedAt,
            cancelledFrom: cancelledFrom,
            progress: progress
        )
    }
}
