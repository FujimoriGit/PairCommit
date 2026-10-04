//
//  ManagerTaskView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Application
import Domain
import SwiftUI

struct ManagerTaskView: View {
    let store: PartnershipStore
    let vision: Vision
    let now: Date

    @State private var input = TaskInput()
    @State private var outcome: Vision.Outcome?
    @State private var failureMessage: String?

    @Environment(\.achievingVision) private var achievingVision
    @Environment(\.presentingFailure) private var presentingFailure
    @Environment(\.playingFeedback) private var playingFeedback

    var body: some View {
        Screen(role: store.role) {
            content
        }
        .animation(.default, value: store.state)
        .animation(.default, value: failureMessage)
        .sensoryFeedback(.error, trigger: failureMessage) { _, message in message != nil }
        .partnershipSettingsLink()
        .partnershipHistoryLink()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                judgement
            }
        }
        .confirmationDialog(
            .managerTaskCloseVisionConfirmationTitle,
            isPresented: Binding(presenting: $outcome),
            presenting: outcome
        ) { outcome in
            Button(outcome.confirmation, role: .destructive) {
                playingFeedback?(outcome == .achieved ? .impact : .warning)
                close(as: outcome)
            }
        } message: { _ in
            Text(.managerTaskCloseVisionConfirmationMessage)
        }
    }
}

// MARK: - Private

private extension ManagerTaskView {
    @ViewBuilder
    var content: some View {
        let tasks = store.state.tasks(for: vision.id)
        VisionCard(
            vision: vision,
            taskProgress: store.state.progress(of: vision.id),
            role: store.role,
            now: now
        )
        NudgeCard(state: store.state, role: store.role, now: now)
        if tasks.isEmpty {
            emptiness
        } else {
            judgementList(tasks.filter(needsJudgement))
            taskList(tasks.filter { !needsJudgement($0) })
        }
        creation
        FailureNote(message: failureMessage)
    }

    @ViewBuilder
    func judgementList(_ tasks: [TaskItem]) -> some View {
        if !tasks.isEmpty {
            SectionHeader(text: String(localized: .managerTaskNeedsDecision))
            ForEach(tasks) { task in
                row(task)
            }
        }
    }

    @ViewBuilder
    func taskList(_ tasks: [TaskItem]) -> some View {
        if !tasks.isEmpty {
            SectionHeader(text: String(localized: .commonTasks))
            ForEach(tasks) { task in
                row(task)
            }
        }
    }

    var emptiness: some View {
        Placeholder(
            symbol: "checklist",
            title: String(localized: .taskListEmptyTitle),
            message: String(localized: .managerTaskEmptyMessage)
        )
    }

    func needsJudgement(_ task: TaskItem) -> Bool {
        switch task.status {
        case .proposed, .reported: true
        case .todo, .approved, .cancelled: false
        }
    }

    func row(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(task.title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Spacer(minLength: 8)
                if let reaction = task.reaction {
                    Text(reaction.emoji)
                }
                DeadlineText(task: task, now: now)
                Text(task.status.label)
                    .marker(task.status.tint)
            }
            TaskDetailText(task: task)
            actions(for: task)
        }
        .card(tinted: task.reaction?.tint)
    }

    @ViewBuilder
    func actions(for task: TaskItem) -> some View {
        switch task.status {
        case .proposed:
            VStack(spacing: 10) {
                Button(.managerTaskAccept) {
                    perform { state, role throws(DomainError) in try state.adoptingTask(task.id, by: role) }
                }
                .buttonStyle(.filled)
                cancellation(of: task)
            }
        case .reported:
            VStack(spacing: 10) {
                Button(.commonApprove) {
                    perform { state, role throws(DomainError) in try state.approvingTask(task.id, by: role) }
                }
                .buttonStyle(.filled)
                HStack(spacing: 10) {
                    Button(.managerTaskSendBack) {
                        perform { state, role throws(DomainError) in try state.returningTask(task.id, by: role) }
                    }
                    .buttonStyle(.soft(feedback: .warning))
                    cancellation(of: task)
                }
            }
        case .todo:
            cancellation(of: task)
        case .approved, .cancelled:
            EmptyView()
        }
    }

    func cancellation(of task: TaskItem) -> some View {
        Button(.managerTaskCancelTask, role: .destructive) {
            perform { state, role throws(DomainError) in try state.cancellingTask(task.id, by: role) }
        }
        .buttonStyle(.soft)
    }

    var creation: some View {
        Panel(title: String(localized: .managerTaskCreationTitle)) {
            TextField(String(localized: .taskFormTitlePlaceholder), text: $input.title)
                .fieldBox()
            TextField(String(localized: .taskFormDetailPlaceholder), text: $input.detail, axis: .vertical)
                .lineLimit(2...4)
                .fieldBox()
            DeadlineField(deadline: $input.deadline)
            Button(.managerTaskAdd, action: create)
                .buttonStyle(.filled)
                .disabled(!input.isComplete)
        }
    }

    var judgement: some View {
        Menu(.managerTaskJudgeOutcome, systemImage: "flag.checkered") {
            ForEach(Vision.Outcome.allCases, id: \.self) { candidate in
                Button(candidate.label, role: candidate == .abandoned ? .destructive : nil) {
                    outcome = candidate
                }
            }
        }
    }

    // 閉じると保存の前にこの画面が消えるので、結果は画面の外へ知らせる
    func close(as outcome: Vision.Outcome) {
        perform(then: outcome == .achieved ? achievingVision : nil, failed: presentingFailure) { state, role throws(DomainError) in
            try state.closingVision(vision.id, as: outcome, by: role)
        }
    }

    func create() {
        let entered = input
        failureMessage = nil
        Task {
            do throws(PartnershipFailure) {
                try await store.perform { state, role throws(DomainError) in
                    try state.creatingTask(
                        title: entered.title,
                        detail: entered.detail,
                        deadline: entered.deadline,
                        by: role
                    ).state
                }
                failureMessage = nil
                input = .init()
            } catch {
                failureMessage = error.message
            }
        }
    }

    func perform(
        then succeeded: (@MainActor () -> Void)? = nil,
        failed: (@MainActor (String) -> Void)? = nil,
        _ transform: @escaping @Sendable (PartnershipState, Role) throws(DomainError) -> PartnershipState
    ) {
        failureMessage = nil
        Task {
            do throws(PartnershipFailure) {
                try await store.perform(transform)
                failureMessage = nil
                succeeded?()
            } catch {
                if let failed {
                    failed(error.message)
                } else {
                    failureMessage = error.message
                }
            }
        }
    }
}

#Preview("管理者のタスク採用待ち") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        ManagerTaskView(store: .preview(
            role: .manager,
            visions: [vision],
            tasks: [
                .preview(
                    visionID: vision.id,
                    title: "毎朝体重を記録する",
                    detail: "起きてトイレのあと、朝食の前に測る",
                    status: .proposed
                ),
                .preview(visionID: vision.id, title: "週3でジムに行く", status: .todo, createdBy: .manager)
            ]
        ), vision: vision, now: .preview)
    }
}

#Preview("管理者のタスク承認待ち") {
    NavigationStack {
        let vision = Vision.preview(status: .active, deadline: .preview(daysLater: 30))
        ManagerTaskView(store: .preview(
            role: .manager,
            visions: [vision],
            tasks: [
                .preview(visionID: vision.id, title: "週3でジムに行く", status: .reported, reaction: .happy, deadline: .preview(daysLater: 30)),
                .preview(visionID: vision.id, title: "夜10時以降は食べない", status: .todo, reaction: .uneasy),
                .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .approved)
            ]
        ), vision: vision, now: .preview)
    }
}

#Preview("管理者のタスクなし") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        ManagerTaskView(store: .preview(role: .manager, visions: [vision]), vision: vision, now: .preview)
    }
}

#Preview("管理者の催促") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        ManagerTaskView(
            store: .preview(
                role: .manager,
                visions: [vision],
                tasks: [
                    .preview(
                        visionID: vision.id,
                        title: "週3でジムに行く",
                        status: .reported,
                        statusChangedAt: .preview(daysLater: -3)
                    )
                ]
            ),
            vision: vision,
            now: .preview
        )
    }
}

#Preview("管理者の感情ヒートマップ") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        ManagerTaskView(
            store: .preview(
                role: .manager,
                visions: [vision],
                tasks: [
                    .preview(visionID: vision.id, title: "週3でジムに行く", status: .todo, reaction: .angry),
                    .preview(visionID: vision.id, title: "夜10時以降は食べない", status: .todo, reaction: .uneasy),
                    .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .todo, reaction: .happy),
                    .preview(visionID: vision.id, title: "週末に献立を決める", status: .todo)
                ]
            ),
            vision: vision,
            now: .preview
        )
    }
}
