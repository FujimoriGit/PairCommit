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
    /// 書いた順に並ぶ。
    public let notes: [Note]
    /// 最後に書かれた書き込みの番号。まだ無ければ 0。
    public let lastNoteNumber: Int

    public init(
        pairing: Pairing? = nil,
        visions: [Vision] = [],
        tasks: [TaskItem] = [],
        notes: [Note] = [],
        lastNoteNumber: Int = 0
    ) {
        self.pairing = pairing
        self.visions = visions
        self.tasks = tasks
        self.notes = notes.sorted { $0.number < $1.number }
        self.lastNoteNumber = lastNoteNumber
    }

    // 書き込みを持つ前の版が残した状態も読めるよう、無い項目は空として読む
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pairing: try container.decodeIfPresent(Pairing.self, forKey: .pairing),
            visions: try container.decode([Vision].self, forKey: .visions),
            tasks: try container.decode([TaskItem].self, forKey: .tasks),
            notes: try container.decodeIfPresent([Note].self, forKey: .notes) ?? [],
            lastNoteNumber: try container.decodeIfPresent(Int.self, forKey: .lastNoteNumber) ?? 0
        )
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

    public func notes(on subject: Note.Subject) -> [Note] {
        notes.filter { $0.subject == subject }
    }
}

// MARK: - ペアリング

extension PartnershipState {
    public func establishingPairing(
        ownerRole: Role,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws(PairingEstablishmentError) -> Self {
        guard pairing == nil else { throw .alreadyPaired }
        return .init(
            pairing: Pairing(id: id, ownerRole: ownerRole, createdAt: now),
            visions: visions,
            tasks: tasks,
            notes: notes,
            lastNoteNumber: lastNoteNumber
        )
    }

    /// 自分の名前を決める。決められるのは操作した本人の名前だけ。
    public func naming(_ name: String, by role: Role) throws(NamingError) -> Self {
        guard let pairing else { throw .notPaired }
        guard let name = nonBlank(name) else { throw .blankName }
        return .init(
            pairing: pairing.naming(role, as: name),
            visions: visions,
            tasks: tasks,
            notes: notes,
            lastNoteNumber: lastNoteNumber
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
    ) throws(VisionDraftingError) -> (state: Self, visionID: Vision.ID) {
        let vision = try newVision(content, by: role, id: id, status: .draft, now: now)
        return (updating(visions: visions + [vision]), vision.id)
    }

    public func revisingVision(
        _ id: Vision.ID,
        to content: Vision.Content,
        by role: Role,
        now: Date = Date()
    ) throws(VisionRevisionError) -> Self {
        try revising(id, to: content, into: .draft, by: role, now: now)
    }

    /// 書いたビジョンを、下書きを経ずに管理者へ提出する。
    public func submittingVision(
        _ content: Vision.Content,
        by role: Role,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws(VisionDraftingError) -> (state: Self, visionID: Vision.ID) {
        let vision = try newVision(content, by: role, id: id, status: .proposed, now: now)
        return (updating(visions: visions + [vision]), vision.id)
    }

    /// 差し戻されたビジョンを書き直し、そのまま提出し直す。
    public func resubmittingVision(
        _ id: Vision.ID,
        as content: Vision.Content,
        by role: Role,
        now: Date = Date()
    ) throws(VisionRevisionError) -> Self {
        try revising(id, to: content, into: .proposed, by: role, now: now)
    }

    public func discardingVision(_ id: Vision.ID, by role: Role) throws(VisionDiscardingError) -> Self {
        guard role == .player else { throw .notPlayer }
        guard let vision = self.vision(id) else { throw .visionNotFound }
        guard vision.status == .draft else { throw .notDraft }
        return updating(
            visions: visions.filter { $0.id != id },
            notes: notes.filter { $0.subject != .vision(id) }
        )
    }

    public func proposingVision(_ id: Vision.ID, by role: Role, now: Date = Date()) throws(VisionProposalError) -> Self {
        guard role == .player else { throw .notPlayer }
        guard let vision = self.vision(id) else { throw .visionNotFound }
        guard vision.status == .draft else { throw .notDraft }
        guard isUpcoming(vision.deadline, at: now) else { throw .pastDeadline }
        return replacing(vision.with(status: .proposed))
    }

    public func approvingVision(_ id: Vision.ID, by role: Role, now: Date = Date()) throws(VisionApprovalError) -> Self {
        guard role == .manager else { throw .notManager }
        guard let vision = self.vision(id) else { throw .visionNotFound }
        guard vision.status == .proposed else { throw .notProposed }
        guard activeVision == nil else { throw .activeVisionExists }
        guard isUpcoming(vision.deadline, at: now) else { throw .pastDeadline }
        return replacing(vision.with(status: .active))
    }

    public func rejectingVision(_ id: Vision.ID, by role: Role) throws(VisionRejectionError) -> Self {
        guard role == .manager else { throw .notManager }
        guard let vision = self.vision(id) else { throw .visionNotFound }
        guard vision.status == .proposed else { throw .notProposed }
        return replacing(vision.with(status: .draft))
    }

    public func closingVision(
        _ id: Vision.ID,
        as outcome: Vision.Outcome,
        by role: Role,
        now: Date = Date()
    ) throws(VisionClosingError) -> Self {
        guard role == .manager else { throw .notManager }
        guard let vision = self.vision(id) else { throw .visionNotFound }
        guard vision.status == .active else { throw .notActive }
        let cancelled = tasks.map { task in
            task.visionID == id && task.status.isOpen ? task.with(status: .cancelled, at: now) : task
        }
        return replacing(vision.with(status: outcome.status)).updating(tasks: cancelled)
    }
}

// MARK: - タスク操作

extension PartnershipState {
    public func creatingTask(
        title: String,
        detail: String? = nil,
        deadline: Date? = nil,
        by role: Role,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws(TaskCreationError) -> (state: Self, taskID: TaskItem.ID) {
        guard let vision = activeVision else { throw .noActiveVision }
        guard let title = nonBlank(title) else { throw .blankTitle }
        guard isUpcoming(deadline, at: now) else { throw .pastDeadline }
        let task = TaskItem(
            id: id,
            visionID: vision.id,
            title: title,
            detail: nonBlank(detail),
            status: role == .manager ? .todo : .proposed,
            createdBy: role,
            reaction: nil,
            deadline: deadline,
            createdAt: now,
            statusChangedAt: now
        )
        return (updating(tasks: tasks + [task]), task.id)
    }

    public func adoptingTask(_ id: TaskItem.ID, by role: Role, now: Date = Date()) throws(TaskAdoptionError) -> Self {
        guard role == .manager else { throw .notManager }
        guard let task = self.task(id) else { throw .taskNotFound }
        guard task.status == .proposed else { throw .notProposed }
        guard isUpcoming(task.deadline, at: now) else { throw .pastDeadline }
        return replacing(task.with(status: .todo, at: now))
    }

    public func reportingTask(_ id: TaskItem.ID, by role: Role, now: Date = Date()) throws(TaskReportError) -> Self {
        guard role == .player else { throw .notPlayer }
        guard let task = self.task(id) else { throw .taskNotFound }
        guard task.status == .todo else { throw .notTodo }
        return replacing(task.with(status: .reported, at: now))
    }

    /// `feedback` が空白だけなら、フィードバックは残さない。
    public func approvingTask(
        _ id: TaskItem.ID,
        feedback: String? = nil,
        by role: Role,
        noteID: UUID = UUID(),
        now: Date = Date()
    ) throws(TaskApprovalError) -> Self {
        guard role == .manager else { throw .notManager }
        guard let task = self.task(id) else { throw .taskNotFound }
        guard task.status == .reported else { throw .notReported }
        let approved = replacing(task.with(status: .approved, at: now))
        guard let feedback = nonBlank(feedback) else { return approved }
        return approved.appendingNote(feedback, kind: .feedback, on: .task(id), by: role, id: noteID, now: now)
    }

    /// `feedback` は空白だけにはできない。
    public func returningTask(
        _ id: TaskItem.ID,
        feedback: String,
        by role: Role,
        noteID: UUID = UUID(),
        now: Date = Date()
    ) throws(TaskReturnError) -> Self {
        guard role == .manager else { throw .notManager }
        guard let task = self.task(id) else { throw .taskNotFound }
        guard task.status == .reported else { throw .notReported }
        guard let feedback = nonBlank(feedback) else { throw .blankFeedback }
        return replacing(task.with(status: .todo, at: now))
            .appendingNote(feedback, kind: .feedback, on: .task(id), by: role, id: noteID, now: now)
    }

    public func cancellingTask(_ id: TaskItem.ID, by role: Role, now: Date = Date()) throws(TaskCancellationError) -> Self {
        guard role == .manager else { throw .notManager }
        guard let task = self.task(id) else { throw .taskNotFound }
        guard task.status.isOpen else { throw .alreadyClosed }
        return replacing(task.with(status: .cancelled, at: now))
    }

    /// 取り消したタスクを、取り消す前の状態に戻す。戻せるのは、ビジョンが進行中の間だけ。
    public func restoringTask(_ id: TaskItem.ID, by role: Role, now: Date = Date()) throws(TaskRestorationError) -> Self {
        guard role == .manager else { throw .notManager }
        guard let task = self.task(id) else { throw .taskNotFound }
        guard task.status == .cancelled, task.visionID == activeVision?.id,
              let previous = task.cancelledFrom, previous.isOpen else {
            throw .notRestorable
        }
        return replacing(task.with(status: previous, at: now))
    }

    public func settingReaction(_ reaction: Reaction?, on id: TaskItem.ID, by role: Role) throws(ReactionError) -> Self {
        guard role == .player else { throw .notPlayer }
        guard let task = self.task(id) else { throw .taskNotFound }
        return replacing(task.with(reaction: reaction))
    }

    /// タスクの進捗率（0〜100）を決める。決められるのは、採用してから承認するまでの間だけ。
    public func settingProgress(_ percent: Int, on id: TaskItem.ID, by role: Role) throws(ProgressError) -> Self {
        guard role == .manager else { throw .notManager }
        guard let task = self.task(id) else { throw .taskNotFound }
        guard task.status == .todo || task.status == .reported else { throw .notInProgress }
        guard (0...100).contains(percent) else { throw .outOfRange }
        return replacing(task.with(progress: percent))
    }
}

// MARK: - 書き込み

extension PartnershipState {
    /// 閉じていないビジョンか、進行中のビジョンのタスクに書き込む。
    public func writingNote(
        _ body: String,
        kind: Note.StandaloneKind,
        on subject: Note.Subject,
        by role: Role,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws(NoteWritingError) -> Self {
        guard kind.isWritable(by: role) else { throw .notPlayer }
        guard let body = nonBlank(body) else { throw .blankBody }
        switch subject {
        case .vision(let visionID):
            guard let vision = self.vision(visionID) else { throw .subjectNotFound }
            guard vision.outcome == nil else { throw .subjectClosed }
        case .task(let taskID):
            guard let task = self.task(taskID) else { throw .subjectNotFound }
            guard task.visionID == activeVision?.id else { throw .subjectClosed }
        }
        return appendingNote(body, kind: kind.kind, on: subject, by: role, id: id, now: now)
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

// MARK: - 相手の操作

extension PartnershipState {
    /// `previous` からこの状態までに、相手が `role` に向けて行った操作。別のペアの状態と比べたときは空。
    public func partnerActions(since previous: Self, for role: Role) -> [PartnerAction] {
        guard pairing?.id == previous.pairing?.id else { return [] }
        let visionActions = visions.compactMap { vision in
            action(on: vision, from: previous.visions.first { $0.id == vision.id }?.status)
        }
        let added = notes.filter { note in !previous.notes.contains { $0.id == note.id } }
        let taskActions = tasks.flatMap { task in
            actions(
                on: task,
                from: previous.tasks.first { $0.id == task.id },
                feedback: added.last { $0.kind == .feedback && $0.subject == .task(task.id) }?.id
            )
        }
        let attached = Set(taskActions.compactMap(\.feedback))
        let noteActions = added
            .filter { !attached.contains($0.id) }
            .map { PartnerAction.noteWritten($0.id, author: $0.author) }
        return (visionActions + taskActions + noteActions).filter { $0.recipient == role }
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

    func action(on vision: Vision, from before: Vision.Status?) -> PartnerAction? {
        guard vision.status != before else { return nil }
        switch vision.status {
        case .proposed: return .visionProposed(vision.id)
        case .active: return .visionApproved(vision.id)
        case .draft: return before == .proposed ? .visionReturned(vision.id) : nil
        case .achieved, .abandoned: return vision.outcome.map { .visionClosed(vision.id, $0) }
        }
    }

    func actions(on task: TaskItem, from previous: TaskItem?, feedback: Note.ID?) -> [PartnerAction] {
        let creation: PartnerAction? = switch (previous, task.createdBy) {
        case (nil, .manager): .taskAdded(task.id)
        case (nil, .player): .taskProposed(task.id)
        case (.some, _): nil
        }
        let reaction = task.reaction.flatMap { $0 == previous?.reaction ? nil : PartnerAction.reactionChanged(task.id, $0) }
        let progress = task.progress.flatMap { $0 == previous?.progress ? nil : PartnerAction.progressChanged(task.id, $0) }
        let before = previous?.status ?? (task.createdBy == .manager ? .todo : .proposed)
        return [creation, statusAction(on: task, from: before, feedback: feedback), reaction, progress].compactMap { $0 }
    }

    func statusAction(on task: TaskItem, from before: TaskItem.Status, feedback: Note.ID?) -> PartnerAction? {
        guard task.status != before else { return nil }
        switch (before, task.status) {
        case (.proposed, .todo): return .taskAdopted(task.id)
        case (.reported, .todo): return .taskReturned(task.id, feedback: feedback)
        case (_, .reported): return .taskReported(task.id)
        case (_, .approved): return .taskApproved(task.id, feedback: feedback)
        case (_, .cancelled): return task.visionID == activeVision?.id ? .taskCancelled(task.id) : nil
        case (_, .proposed), (_, .todo): return nil
        }
    }

    func updating(
        visions: [Vision]? = nil,
        tasks: [TaskItem]? = nil,
        notes: [Note]? = nil,
        lastNoteNumber: Int? = nil
    ) -> Self {
        .init(
            pairing: pairing,
            visions: visions ?? self.visions,
            tasks: tasks ?? self.tasks,
            notes: notes ?? self.notes,
            lastNoteNumber: lastNoteNumber ?? self.lastNoteNumber
        )
    }

    func appendingNote(
        _ body: String,
        kind: Note.Kind,
        on subject: Note.Subject,
        by role: Role,
        id: UUID,
        now: Date
    ) -> Self {
        let note = Note(
            id: id,
            subject: subject,
            kind: kind,
            author: role,
            number: lastNoteNumber + 1,
            body: body,
            writtenAt: now
        )
        return updating(notes: notes + [note], lastNoteNumber: note.number)
    }

    func vision(_ id: Vision.ID) -> Vision? {
        visions.first { $0.id == id }
    }

    func task(_ id: TaskItem.ID) -> TaskItem? {
        tasks.first { $0.id == id }
    }

    func replacing(_ vision: Vision) -> Self {
        updating(visions: visions.map { $0.id == vision.id ? vision : $0 })
    }

    func replacing(_ task: TaskItem) -> Self {
        updating(tasks: tasks.map { $0.id == task.id ? task : $0 })
    }

    func nonBlank(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    func isUpcoming(_ deadline: Date?, at now: Date) -> Bool {
        deadline.map { $0 > now } ?? true
    }

    func newVision(
        _ content: Vision.Content,
        by role: Role,
        id: UUID,
        status: Vision.Status,
        now: Date
    ) throws(VisionDraftingError) -> Vision {
        guard role == .player else { throw .notPlayer }
        guard let statement = nonBlank(content.statement) else { throw .blankStatement }
        guard let doneCriteria = nonBlank(content.doneCriteria) else { throw .blankDoneCriteria }
        guard isUpcoming(content.deadline, at: now) else { throw .pastDeadline }
        return Vision(
            id: id,
            statement: statement,
            doneCriteria: doneCriteria,
            deadline: content.deadline,
            why: nonBlank(content.why),
            status: status,
            createdAt: now
        )
    }

    func revising(
        _ id: Vision.ID,
        to content: Vision.Content,
        into status: Vision.Status,
        by role: Role,
        now: Date
    ) throws(VisionRevisionError) -> Self {
        guard role == .player else { throw .notPlayer }
        guard let vision = self.vision(id) else { throw .visionNotFound }
        guard vision.status == .draft else { throw .notDraft }
        guard let statement = nonBlank(content.statement) else { throw .blankStatement }
        guard let doneCriteria = nonBlank(content.doneCriteria) else { throw .blankDoneCriteria }
        guard isUpcoming(content.deadline, at: now) else { throw .pastDeadline }
        let revised = vision
            .with(statement: statement, doneCriteria: doneCriteria, deadline: content.deadline, why: nonBlank(content.why))
            .with(status: status)
        return replacing(revised)
    }
}
