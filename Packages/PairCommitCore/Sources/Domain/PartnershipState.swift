//
//  PartnershipState.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

/// ペアの全状態を束ねる集約ルート。不変条件はすべてここで守る:
/// - active な Vision は高々1個。
/// - 状態遷移は定義されたライフサイクルに沿う。
/// - 操作はロール権限（Manager / Player の非対称性）でガードされる。
/// - Vision を閉じるとき、配下の未完了タスクも一緒に閉じる（cancelled）。
///
/// 同期層（`SyncRepository`）と受け渡しする単位でもある。CloudKit の存在は知らない。
public struct PartnershipState: Sendable, Codable, Equatable {
    public private(set) var pairing: Pairing?
    public private(set) var visions: [Vision]
    public private(set) var tasks: [TaskItem]

    /// 空の状態から始めるか、同期層が受信データからスナップショットを再構築する。
    public init(pairing: Pairing? = nil, visions: [Vision] = [], tasks: [TaskItem] = []) {
        self.pairing = pairing
        self.visions = visions
        self.tasks = tasks
    }

    /// 中心の不変条件により高々1個。
    public var activeVision: Vision? {
        visions.first { $0.status == .active }
    }

    public func tasks(for visionID: Vision.ID) -> [TaskItem] {
        tasks.filter { $0.visionID == visionID }
    }
}

// MARK: - ペアリング

extension PartnershipState {
    /// ペアを確立する。ロールはここで固定される（スワップなし）。
    public mutating func establishPairing(ownerRole: Role, id: UUID = UUID(), now: Date = Date()) throws {
        guard pairing == nil else { throw DomainError.alreadyPaired }
        pairing = Pairing(id: id, ownerRole: ownerRole, createdAt: now)
    }
}

// MARK: - Vision 操作

extension PartnershipState {
    /// プレイヤーがビジョンを起案する（draft）。
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

    /// プレイヤーが起案を管理者に提出する（draft → proposed）。
    public mutating func proposeVision(_ id: Vision.ID, by role: Role) throws {
        try require(role, is: .player)
        try transitionVision(id, from: [.draft], to: .proposed)
    }

    /// 管理者が承認して確定する（proposed → active）。active が既にあれば失敗。
    public mutating func approveVision(_ id: Vision.ID, by role: Role) throws {
        try require(role, is: .manager)
        guard activeVision == nil else { throw DomainError.activeVisionAlreadyExists }
        try transitionVision(id, from: [.proposed], to: .active)
    }

    /// 管理者が差し戻す（proposed → draft）。
    public mutating func rejectVision(_ id: Vision.ID, by role: Role) throws {
        try require(role, is: .manager)
        try transitionVision(id, from: [.proposed], to: .draft)
    }

    /// 管理者が active な Vision を閉じる（達成/中止は管理者の質的判断）。
    /// 配下の未完了タスクも一緒に閉じる（残骸を引きずらない）。
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
    /// タスクを作る。active な Vision の下にしか作れない。
    /// 管理者の生成は即 todo、プレイヤーの起案は proposed（管理者の採用待ち）。
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

    /// 管理者がプレイヤー起案を採用する（proposed → todo）。
    public mutating func adoptTask(_ id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .manager)
        try transitionTask(id, from: [.proposed], to: .todo)
    }

    /// プレイヤーが完了を報告する（todo → reported）。承認待ちで止まる。
    public mutating func reportTask(_ id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .player)
        try transitionTask(id, from: [.todo], to: .reported)
    }

    /// 管理者が完了を承認する（reported → approved）。完了承認は管理者が握る。
    public mutating func approveTask(_ id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .manager)
        try transitionTask(id, from: [.reported], to: .approved)
    }

    /// 管理者が報告を差し戻す（reported → todo）。
    public mutating func returnTask(_ id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .manager)
        try transitionTask(id, from: [.reported], to: .todo)
    }

    /// 管理者が未完了タスクを取り下げる（起案の却下を含む）。
    public mutating func cancelTask(_ id: TaskItem.ID, by role: Role) throws {
        try require(role, is: .manager)
        try transitionTask(id, from: [.proposed, .todo, .reported], to: .cancelled)
    }

    /// プレイヤーが感情を表明する（上書き・nil で取り下げ）。唯一の主体性。
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
