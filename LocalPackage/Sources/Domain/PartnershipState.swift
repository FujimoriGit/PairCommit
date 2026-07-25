//
//  PartnershipState.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

public struct PartnershipState: Sendable, Codable, Equatable {
    public private(set) var pairing: Pairing?
    public private(set) var visions: [Vision]
    public private(set) var tasks: [TaskItem]

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
    public mutating func establishPairing(ownerRole: Role, id: UUID = UUID(), now: Date = Date()) throws {
        guard pairing == nil else { throw DomainError.alreadyPaired }
        pairing = Pairing(id: id, ownerRole: ownerRole, createdAt: now)
    }
}

// MARK: - Vision 操作

extension PartnershipState {
    @discardableResult
    public mutating func draftVision(
        statement: String,
        doneCriteria: String,
        deadline: Date? = nil,
        why: String? = nil,
        by role: Role,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws -> Vision.ID {
        try require(role, is: .player)
        let vision = Vision(
            id: id,
            statement: statement,
            doneCriteria: doneCriteria,
            deadline: deadline,
            why: why,
            status: .draft,
            createdAt: now
        )
        visions.append(vision)
        return vision.id
    }

    public mutating func proposeVision(_ id: Vision.ID, by role: Role) throws {
        try require(role, is: .player)
        try transitionVision(id, from: [.draft], to: .proposed)
    }

    public mutating func approveVision(_ id: Vision.ID, by role: Role) throws {
        try require(role, is: .manager)
        guard activeVision == nil else { throw DomainError.activeVisionAlreadyExists }
        try transitionVision(id, from: [.proposed], to: .active)
    }

    public mutating func rejectVision(_ id: Vision.ID, by role: Role) throws {
        try require(role, is: .manager)
        try transitionVision(id, from: [.proposed], to: .draft)
    }

    public mutating func closeVision(_ id: Vision.ID, as outcome: Vision.Outcome, by role: Role) throws {
        try require(role, is: .manager)
        try transitionVision(id, from: [.active], to: outcome.status)
        for index in tasks.indices where tasks[index].visionID == id && tasks[index].status.isOpen {
            tasks[index].status = .cancelled
        }
    }
}

// MARK: - タスク操作

extension PartnershipState {
    @discardableResult
    public mutating func createTask(
        title: String,
        deadline: Date? = nil,
        by role: Role,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws -> TaskItem.ID {
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
        tasks.append(task)
        return task.id
    }

    public mutating func adoptTask(_ id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .manager)
        try transitionTask(id, from: [.proposed], to: .todo)
    }

    public mutating func reportTask(_ id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .player)
        try transitionTask(id, from: [.todo], to: .reported)
    }

    public mutating func approveTask(_ id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .manager)
        try transitionTask(id, from: [.reported], to: .approved)
    }

    public mutating func returnTask(_ id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .manager)
        try transitionTask(id, from: [.reported], to: .todo)
    }

    public mutating func cancelTask(_ id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .manager)
        try transitionTask(id, from: [.proposed, .todo, .reported], to: .cancelled)
    }

    public mutating func setReaction(_ reaction: Reaction?, on id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .player)
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            throw DomainError.taskNotFound(id)
        }
        tasks[index].reaction = reaction
    }
}

// MARK: - Private

private extension PartnershipState {
    func require(_ role: Role, is required: Role) throws {
        guard role == required else { throw DomainError.roleForbidden(required: required) }
    }

    mutating func transitionVision(
        _ id: Vision.ID,
        from allowed: Set<Vision.Status>,
        to newStatus: Vision.Status
    ) throws {
        guard let index = visions.firstIndex(where: { $0.id == id }) else {
            throw DomainError.visionNotFound(id)
        }
        guard allowed.contains(visions[index].status) else {
            throw DomainError.invalidVisionTransition(from: visions[index].status)
        }
        visions[index].status = newStatus
    }

    mutating func transitionTask(
        _ id: TaskItem.ID,
        from allowed: Set<TaskItem.Status>,
        to newStatus: TaskItem.Status
    ) throws {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            throw DomainError.taskNotFound(id)
        }
        guard allowed.contains(tasks[index].status) else {
            throw DomainError.invalidTaskTransition(from: tasks[index].status)
        }
        tasks[index].status = newStatus
    }
}
