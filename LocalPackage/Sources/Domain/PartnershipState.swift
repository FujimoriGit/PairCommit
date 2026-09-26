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

    public var lastAchievedVision: Vision? {
        visions.last { $0.status == .achieved }
    }

    public var closedVisions: [ClosedVision] {
        visions.compactMap(ClosedVision.init).sorted { $0.vision.createdAt > $1.vision.createdAt }
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
        _ content: Vision.Content,
        by role: Role,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws(DomainError) -> (state: Self, visionID: Vision.ID) {
        try requiring(role, is: .player)
        let vision = Vision(
            id: id,
            statement: try requiringText(content.statement),
            doneCriteria: try requiringText(content.doneCriteria),
            deadline: content.deadline,
            why: nonBlank(content.why),
            status: .draft,
            createdAt: now
        )
        return (updating(visions: visions + [vision]), vision.id)
    }

    public func revisingVision(
        _ id: Vision.ID,
        to content: Vision.Content,
        by role: Role
    ) throws(DomainError) -> Self {
        try requiring(role, is: .player)
        let statement = try requiringText(content.statement)
        let doneCriteria = try requiringText(content.doneCriteria)
        let revised = try requiringDraft(id)
            .with(statement: statement, doneCriteria: doneCriteria, deadline: content.deadline, why: nonBlank(content.why))
        return updating(visions: visions.map { $0.id == id ? revised : $0 })
    }

    public func discardingVision(_ id: Vision.ID, by role: Role) throws(DomainError) -> Self {
        try requiring(role, is: .player)
        _ = try requiringDraft(id)
        return updating(visions: visions.filter { $0.id != id })
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
        by role: Role,
        now: Date = Date()
    ) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        let closed = try transitioningVision(id, from: [.active], to: outcome.status)
        let cancelled = tasks.map { task in
            task.visionID == id && task.status.isOpen ? task.with(status: .cancelled, at: now) : task
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
        let title = try requiringText(title)
        let task = TaskItem(
            id: id,
            visionID: vision.id,
            title: title,
            status: role == .manager ? .todo : .proposed,
            createdBy: role,
            reaction: nil,
            deadline: deadline,
            createdAt: now,
            statusChangedAt: now
        )
        return (updating(tasks: tasks + [task]), task.id)
    }

    public func adoptingTask(_ id: TaskItem.ID, by role: Role, now: Date = Date()) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        return updating(tasks: try transitioningTask(id, from: [.proposed], to: .todo, at: now))
    }

    public func reportingTask(_ id: TaskItem.ID, by role: Role, now: Date = Date()) throws(DomainError) -> Self {
        try requiring(role, is: .player)
        return updating(tasks: try transitioningTask(id, from: [.todo], to: .reported, at: now))
    }

    public func approvingTask(_ id: TaskItem.ID, by role: Role, now: Date = Date()) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        return updating(tasks: try transitioningTask(id, from: [.reported], to: .approved, at: now))
    }

    public func returningTask(_ id: TaskItem.ID, by role: Role, now: Date = Date()) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        return updating(tasks: try transitioningTask(id, from: [.reported], to: .todo, at: now))
    }

    public func cancellingTask(_ id: TaskItem.ID, by role: Role, now: Date = Date()) throws(DomainError) -> Self {
        try requiring(role, is: .manager)
        return updating(tasks: try transitioningTask(id, from: [.proposed, .todo, .reported], to: .cancelled, at: now))
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

// MARK: - 催促

extension PartnershipState {
    public func nudges(
        for role: Role,
        now: Date = Date(),
        dueSoonWithin: TimeInterval = Nudge.dueSoonWithin,
        approvalStalledAfter: TimeInterval = Nudge.approvalStalledAfter
    ) -> [Nudge] {
        nudgeWindows(for: role, dueSoonWithin: dueSoonWithin, approvalStalledAfter: approvalStalledAfter)
            .filter { $0.startsAt < now && now <= ($0.endsAt ?? .distantFuture) }
            .map(\.nudge)
    }

    /// まだ始まっていない催促と、それが始まる時刻。その時刻を過ぎると `nudges(for:now:)` に現れる。
    public func upcomingNudges(
        for role: Role,
        now: Date = Date(),
        dueSoonWithin: TimeInterval = Nudge.dueSoonWithin,
        approvalStalledAfter: TimeInterval = Nudge.approvalStalledAfter
    ) -> [Nudge: Date] {
        let windows = nudgeWindows(for: role, dueSoonWithin: dueSoonWithin, approvalStalledAfter: approvalStalledAfter)
        return Dictionary(
            windows.filter { $0.startsAt >= now }.map { ($0.nudge, $0.startsAt) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

// MARK: - Private

private extension PartnershipState {
    struct NudgeWindow {
        let nudge: Nudge
        let startsAt: Date
        let endsAt: Date?
    }

    func nudgeWindows(
        for role: Role,
        dueSoonWithin: TimeInterval,
        approvalStalledAfter: TimeInterval
    ) -> [NudgeWindow] {
        guard let vision = activeVision else { return [] }

        var found: [NudgeWindow] = []
        if let deadline = vision.deadline {
            found.append(.init(nudge: .visionOverdue(vision.id), startsAt: deadline, endsAt: nil))
        }
        for task in tasks(for: vision.id) {
            switch task.status {
            case .todo:
                if let deadline = task.deadline {
                    found.append(.init(nudge: .taskOverdue(task.id), startsAt: deadline, endsAt: nil))
                    found.append(.init(
                        nudge: .taskDueSoon(task.id),
                        startsAt: deadline.addingTimeInterval(-dueSoonWithin),
                        endsAt: deadline
                    ))
                }
            case .reported:
                found.append(.init(
                    nudge: .approvalStalled(task.id),
                    startsAt: task.statusChangedAt.addingTimeInterval(approvalStalledAfter),
                    endsAt: nil
                ))
            case .proposed, .approved, .cancelled:
                break
            }
        }
        return found.filter { $0.nudge.recipient == role }
    }

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

    func requiringText(_ text: String) throws(DomainError) -> String {
        guard let text = nonBlank(text) else { throw DomainError.blankText }
        return text
    }

    func nonBlank(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    func requiringDraft(_ id: Vision.ID) throws(DomainError) -> Vision {
        guard let vision = visions.first(where: { $0.id == id }) else {
            throw DomainError.visionNotFound(id)
        }
        guard vision.status == .draft else {
            throw DomainError.invalidVisionTransition(from: vision.status)
        }
        return vision
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
        to newStatus: TaskItem.Status,
        at changedAt: Date
    ) throws(DomainError) -> [TaskItem] {
        guard let current = tasks.first(where: { $0.id == id }) else {
            throw DomainError.taskNotFound(id)
        }
        guard allowed.contains(current.status) else {
            throw DomainError.invalidTaskTransition(from: current.status)
        }
        return tasks.map { $0.id == id ? $0.with(status: newStatus, at: changedAt) : $0 }
    }
}
