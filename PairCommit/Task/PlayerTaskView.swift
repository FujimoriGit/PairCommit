//
//  PlayerTaskView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Application
import Domain
import SwiftUI

struct PlayerTaskView: View {
    let store: PartnershipStore
    let vision: Vision
    let now: Date

    @State private var input = TaskInput()
    @State private var failureMessage: String?
    @State private var feedback = FeedbackCue()

    var body: some View {
        Screen(role: store.role) {
            content
        }
        .animation(.default, value: store.state)
        .animation(.default, value: failureMessage)
        .sensoryFeedback(.error, trigger: failureMessage) { _, message in message != nil }
        .sensoryFeedback(trigger: feedback) { _, cue in cue.feedback }
        .partnershipSettingsLink()
        .partnershipHistoryLink()
    }
}

// MARK: - Private

private extension PlayerTaskView {
    @ViewBuilder
    var content: some View {
        VisionCard(
            vision: vision,
            taskProgress: store.state.progress(of: vision.id),
            role: store.role,
            now: now
        )
        NudgeCard(state: store.state, role: store.role, now: now)
        taskList(store.state.tasks(for: vision.id))
        proposal
        FailureNote(message: failureMessage)
    }

    @ViewBuilder
    func taskList(_ tasks: [TaskItem]) -> some View {
        SectionHeader(text: String(localized: .commonTasks))
        if tasks.isEmpty {
            Placeholder(
                symbol: "checklist",
                title: String(localized: .taskListEmptyTitle),
                message: String(localized: .playerTaskEmptyMessage)
            )
        } else {
            ForEach(tasks) { task in
                row(task)
            }
        }
    }

    func row(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(task.title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Spacer(minLength: 8)
                DeadlineText(task: task, now: now)
                Text(task.status.label)
                    .marker(task.status.tint)
            }
            TaskDetailText(task: task)
            if task.status.isOpen {
                reactions(for: task)
            } else if let reaction = task.reaction {
                Text(reaction.emoji)
                    .font(.title2)
            }
            if task.status == .todo {
                Button {
                    feedback = feedback.playing(.impact(weight: .light))
                    perform(succeeding: .success) { state, role throws(DomainError) in
                        try state.reportingTask(task.id, by: role)
                    }
                } label: {
                    Text(.playerTaskReport)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .card(tinted: task.reaction?.tint)
    }

    func reactions(for task: TaskItem) -> some View {
        HStack(spacing: 8) {
            ForEach(Reaction.allCases, id: \.self) { reaction in
                Button {
                    feedback = feedback.playing(.selection)
                    perform { state, role throws(DomainError) in
                        try state.settingReaction(
                            task.reaction == reaction ? nil : reaction,
                            on: task.id,
                            by: role
                        )
                    }
                } label: {
                    reactionLabel(reaction, chosen: task.reaction == reaction)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(task.reaction == reaction ? .isSelected : [])
            }
        }
    }

    func reactionLabel(_ reaction: Reaction, chosen: Bool) -> some View {
        Text(reaction.emoji)
            .font(.largeTitle)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                chosen ? reaction.tint.opacity(0.22) : Color(.tertiarySystemFill),
                in: .rect(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(reaction.tint, lineWidth: chosen ? 2 : 0)
            }
            .contentShape(.rect)
    }

    var proposal: some View {
        Panel(title: String(localized: .playerTaskProposalTitle)) {
            TextField(String(localized: .taskFormTitlePlaceholder), text: $input.title)
                .fieldBox()
            TextField(String(localized: .taskFormDetailPlaceholder), text: $input.detail, axis: .vertical)
                .lineLimit(2...4)
                .fieldBox()
            DeadlineField(deadline: $input.deadline)
            Button(.commonPropose, action: create)
                .buttonStyle(.filled)
                .disabled(!input.isComplete)
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
        succeeding success: SensoryFeedback? = nil,
        _ transform: @escaping @Sendable (PartnershipState, Role) throws(DomainError) -> PartnershipState
    ) {
        failureMessage = nil
        Task {
            do throws(PartnershipFailure) {
                try await store.perform(transform)
                failureMessage = nil
                if let success {
                    feedback = feedback.playing(success)
                }
            } catch {
                failureMessage = error.message
            }
        }
    }
}

#Preview("プレイヤーのタスク報告前") {
    NavigationStack {
        let vision = Vision.preview(status: .active, deadline: .preview(daysLater: 30))
        PlayerTaskView(store: .preview(
            role: .player,
            visions: [vision],
            tasks: [
                .preview(
                    visionID: vision.id,
                    title: "週3でジムに行く",
                    detail: "筋トレ30分と有酸素20分。行けなかった週は土日に回す",
                    status: .todo,
                    createdBy: .manager,
                    deadline: .preview(daysLater: 30)
                ),
                .preview(visionID: vision.id, title: "夜10時以降は食べない", status: .todo, createdBy: .manager, reaction: .angry)
            ]
        ), vision: vision, now: .preview)
    }
}

#Preview("プレイヤーのタスク採用待ち") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        PlayerTaskView(store: .preview(
            role: .player,
            visions: [vision],
            tasks: [
                .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .proposed),
                .preview(visionID: vision.id, title: "週3でジムに行く", status: .reported, reaction: .happy)
            ]
        ), vision: vision, now: .preview)
    }
}

#Preview("プレイヤーのタスクなし") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        PlayerTaskView(store: .preview(role: .player, visions: [vision]), vision: vision, now: .preview)
    }
}

#Preview("プレイヤーの催促") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        PlayerTaskView(
            store: .preview(
                role: .player,
                visions: [vision],
                tasks: [
                    .preview(
                        visionID: vision.id,
                        title: "週3でジムに行く",
                        status: .todo,
                        createdBy: .manager,
                        deadline: .preview(daysLater: -1)
                    )
                ]
            ),
            vision: vision,
            now: .preview
        )
    }
}

#Preview("プレイヤーの期限間近") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        PlayerTaskView(
            store: .preview(
                role: .player,
                visions: [vision],
                tasks: [
                    .preview(
                        visionID: vision.id,
                        title: "週3でジムに行く",
                        status: .todo,
                        createdBy: .manager,
                        deadline: .preview(daysLater: 2)
                    )
                ]
            ),
            vision: vision,
            now: .preview
        )
    }
}

#Preview("プレイヤーの感情ヒートマップ") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        PlayerTaskView(store: .preview(
            role: .player,
            visions: [vision],
            tasks: [
                .preview(visionID: vision.id, title: "毎日30分歩く", status: .approved, createdBy: .manager, reaction: .happy),
                .preview(visionID: vision.id, title: "間食をやめる", status: .approved, createdBy: .manager, reaction: .angry),
                .preview(visionID: vision.id, title: "夜10時以降は食べない", status: .todo, createdBy: .manager, reaction: .uneasy)
            ]
        ), vision: vision, now: .preview)
    }
}
