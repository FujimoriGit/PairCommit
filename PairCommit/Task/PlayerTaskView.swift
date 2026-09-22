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
    var now = Date()

    @State private var input = TaskInput()
    @State private var failureMessage: String?

    var body: some View {
        Screen(role: store.role) {
            content
        }
        .partnershipReset()
        .partnershipHistoryLink()
    }
}

// MARK: - Private

private extension PlayerTaskView {
    @ViewBuilder
    var content: some View {
        VisionCard(vision: vision, role: store.role, now: now)
        NudgeCard(state: store.state, role: store.role, now: now)
        taskList(store.state.tasks(for: vision.id))
        proposal
        FailureNote(message: failureMessage)
    }

    @ViewBuilder
    func taskList(_ tasks: [TaskItem]) -> some View {
        SectionHeader(text: "タスク")
        if tasks.isEmpty {
            Placeholder(
                symbol: "checklist",
                title: "まだタスクがありません",
                message: "やることを起案すると、ここに並びます"
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
            if task.status.isOpen {
                reactions(for: task)
            } else if let reaction = task.reaction {
                Text(reaction.emoji)
                    .font(.title2)
            }
            if task.status == .todo {
                Button {
                    perform { state throws(DomainError) in try state.reportingTask(task.id, by: store.role) }
                } label: {
                    Text("完了を報告する")
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
                    perform { state throws(DomainError) in
                        try state.settingReaction(
                            task.reaction == reaction ? nil : reaction,
                            on: task.id,
                            by: store.role
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
        Panel(title: "タスクを起案する") {
            TextField("やること", text: $input.title)
                .fieldBox()
            DeadlineField(deadline: $input.deadline)
            Button("起案する", action: create)
                .buttonStyle(.filled)
                .disabled(!input.isComplete)
        }
    }

    func create() {
        let entered = input
        Task {
            do throws(PartnershipFailure) {
                try await store.perform { state throws(DomainError) in
                    try state.creatingTask(title: entered.title, deadline: entered.deadline, by: store.role).state
                }
                failureMessage = nil
                input = .init()
            } catch {
                failureMessage = error.message
            }
        }
    }

    func perform(_ transform: @escaping @Sendable (PartnershipState) throws(DomainError) -> PartnershipState) {
        Task {
            do throws(PartnershipFailure) {
                try await store.perform(transform)
                failureMessage = nil
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
                .preview(visionID: vision.id, title: "週3でジムに行く", status: .todo, createdBy: .manager, deadline: .preview(daysLater: 30)),
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
