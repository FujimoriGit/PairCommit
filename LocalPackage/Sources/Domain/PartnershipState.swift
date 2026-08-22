//
//  PartnershipState.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

public struct PartnershipState: Sendable, Codable, Equatable {
    public let pairing: Pairing?
    public let visions: [Vision]
    public let tasks: [TaskItem]

    public init(pairing: Pairing? = nil, visions: [Vision] = [], tasks: [TaskItem] = []) {
        self.pairing = pairing
        self.visions = visions
        self.tasks = tasks
    }

    public var activeVision: Vision? {
        visions.first { $0.status == .active }
    }

    public func tasks(for visionID: Vision.ID) -> [TaskItem] {
        tasks.filter { $0.visionID == visionID }
    }
}

// MARK: - ペアリング

extension PartnershipState {
    public func establishingPairing(
        ownerRole: Role,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws(DomainError) -> Self {
        guard pairing == nil else { throw DomainError.alreadyPaired }
        return .init(
            pairing: Pairing(id: id, ownerRole: ownerRole, createdAt: now),
            visions: visions,
            tasks: tasks
        )
    }
}

// MARK: - Vision 操作

extension PartnershipState {
    public func draftingVision(
        statement: String,
        doneCriteria: String,
        deadline: Date? = nil,
        why: String? = nil,
        by role: Role,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws(DomainError) -> (state: Self, visionID: Vision.ID) {
        try requiring(role, is: .player)
        let vision = Vision(
            id: id,
            statement: statement,
            doneCriteria: doneCriteria,
            deadline: deadline,
            why: why,
            status: .draft,
            createdAt: now
        )
        return (updating(visions: visions + [vision]), vision.id)
    }

    public func proposingVision(_ id: Vision.ID, by role: Role) throws(DomainError) -> Self {
        try requiring(role, is: .player)
        return updating(visions: try transitioningVision(id, from: [.draft], to: .proposed))
    }

    public func approvingVision(_ id: Vision.ID, by role: Role) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        guard activeVision == nil else { throw DomainError.activeVisionAlreadyExists }
        return updating(visions: try transitioningVision(id, from: [.proposed], to: .active))
    }

    public func rejectingVision(_ id: Vision.ID, by role: Role) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        return updating(visions: try transitioningVision(id, from: [.proposed], to: .draft))
    }

    public func closingVision(
        _ id: Vision.ID,
        as outcome: Vision.Outcome,
        by role: Role
    ) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        let closed = try transitioningVision(id, from: [.active], to: outcome.status)
        let cancelled = tasks.map { task in
            task.visionID == id && task.status.isOpen ? task.with(status: .cancelled) : task
        }
        return updating(visions: closed, tasks: cancelled)
    }
}

// MARK: - タスク操作

extension PartnershipState {
    public func creatingTask(
        title: String,
        deadline: Date? = nil,
        by role: Role,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws(DomainError) -> (state: Self, taskID: TaskItem.ID) {
        guard let vision = activeVision else { throw DomainError.noActiveVision }
        let task = TaskItem(
            id: id,
            visionID: vision.id,
            title: title,
            status: role == .manager ? .todo : .proposed,
            createdBy: role,
            reaction: nil,
            deadline: deadline,
            createdAt: now
        )
        return (updating(tasks: tasks + [task]), task.id)
    }

    public func adoptingTask(_ id: TaskItem.ID, by role: Role) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        return updating(tasks: try transitioningTask(id, from: [.proposed], to: .todo))
    }

    public func reportingTask(_ id: TaskItem.ID, by role: Role) throws(DomainError) -> Self {
        try requiring(role, is: .player)
        return updating(tasks: try transitioningTask(id, from: [.todo], to: .reported))
    }

    public func approvingTask(_ id: TaskItem.ID, by role: Role) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        return updating(tasks: try transitioningTask(id, from: [.reported], to: .approved))
    }

    public func returningTask(_ id: TaskItem.ID, by role: Role) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        return updating(tasks: try transitioningTask(id, from: [.reported], to: .todo))
    }

    public func cancellingTask(_ id: TaskItem.ID, by role: Role) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        return updating(tasks: try transitioningTask(id, from: [.proposed, .todo, .reported], to: .cancelled))
    }

    public func settingReaction(
        _ reaction: Reaction?,
        on id: TaskItem.ID,
        by role: Role
    ) throws(DomainError) -> Self {
        try requiring(role, is: .player)
        guard tasks.contains(where: { $0.id == id }) else { throw DomainError.taskNotFound(id) }
        return updating(tasks: tasks.map { $0.id == id ? $0.with(reaction: reaction) : $0 })
    }
}

// MARK: - Private

private extension PartnershipState {
    func updating(visions: [Vision]? = nil, tasks: [TaskItem]? = nil) -> Self {
        .init(
            pairing: pairing,
            visions: visions ?? self.visions,
            tasks: tasks ?? self.tasks
        )
    }

    func requiring(_ role: Role, is required: Role) throws(DomainError) {
        guard role == required else { throw DomainError.roleForbidden(required: required) }
    }

    func transitioningVision(
        _ id: Vision.ID,
        from allowed: Set<Vision.Status>,
        to newStatus: Vision.Status
    ) throws(DomainError) -> [Vision] {
        guard let current = visions.first(where: { $0.id == id }) else {
            throw DomainError.visionNotFound(id)
        }
        guard allowed.contains(current.status) else {
            throw DomainError.invalidVisionTransition(from: current.status)
        }
        return visions.map { $0.id == id ? $0.with(status: newStatus) : $0 }
    }

    func transitioningTask(
        _ id: TaskItem.ID,
        from allowed: Set<TaskItem.Status>,
        to newStatus: TaskItem.Status
    ) throws(DomainError) -> [TaskItem] {
        guard let current = tasks.first(where: { $0.id == id }) else {
            throw DomainError.taskNotFound(id)
        }
        guard allowed.contains(current.status) else {
            throw DomainError.invalidTaskTransition(from: current.status)
        }
        return tasks.map { $0.id == id ? $0.with(status: newStatus) : $0 }
    }
}
