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
    var now = Date()

    @State private var input = TaskInput()
    @State private var failureMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Role.player.label)
        }
    }
}

// MARK: - Private

private extension PlayerTaskView {
    @ViewBuilder
    var content: some View {
        if let vision = store.state.activeVision {
            Form {
                nudgeSection
                visionSection(vision)
                proposal
                taskList(store.state.tasks(for: vision.id))
                FailureRow(message: failureMessage)
            }
        } else {
            ContentUnavailableView(
                "進行中のビジョンがありません",
                systemImage: "flag",
                description: Text("管理者の承認を待っています")
            )
        }
    }

    var proposal: some View {
        Section("タスクを起案する") {
            TextField("やること", text: $input.title)
            DeadlineField(deadline: $input.deadline)
            Button("起案する") {
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
            .buttonStyle(.borderedProminent)
            .disabled(!input.isComplete)
        }
    }

    @ViewBuilder
    var nudgeSection: some View {
        let nudges = store.state.nudges(for: store.role, now: now)
        if !nudges.isEmpty {
            Section {
                ForEach(nudges, id: \.self) { nudge in
                    Label(nudge.message(in: store.state), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    func visionSection(_ vision: Vision) -> some View {
        Section("ビジョン") {
            Text(vision.statement)
                .font(.headline)
            if let deadline = vision.deadline {
                LabeledContent("期限", value: deadline.formatted(Date.FormatStyle.deadlineFull))
            }
        }
    }

    func taskList(_ tasks: [TaskItem]) -> some View {
        Section("タスク") {
            if tasks.isEmpty {
                Text("まだタスクがありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    row(task)
                }
            }
        }
    }

    func row(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                Spacer()
                DeadlineText(deadline: task.deadline)
                Text(task.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if task.status.isOpen {
                reactions(for: task)
            }
            if task.status == .todo {
                Button("完了を報告する") {
                    perform { state throws(DomainError) in try state.reportingTask(task.id, by: store.role) }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    func reactions(for task: TaskItem) -> some View {
        HStack(spacing: 16) {
            ForEach(Reaction.allCases, id: \.self) { reaction in
                Button(reaction.emoji) {
                    perform { state throws(DomainError) in
                        try state.settingReaction(
                            task.reaction == reaction ? nil : reaction,
                            on: task.id,
                            by: store.role
                        )
                    }
                }
                .opacity(task.reaction == reaction ? 1 : 0.3)
            }
        }
        .buttonStyle(.borderless)
    }

    func perform(_ transform: @escaping (PartnershipState) throws(DomainError) -> PartnershipState) {
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
    let vision = Vision.preview(status: .active, deadline: .preview(daysLater: 30))
    PlayerTaskView(store: .preview(
        role: .player,
        visions: [vision],
        tasks: [
            .preview(visionID: vision.id, title: "週3でジムに行く", status: .todo, createdBy: .manager, deadline: .preview(daysLater: 30)),
            .preview(visionID: vision.id, title: "夜10時以降は食べない", status: .todo, createdBy: .manager, reaction: .angry)
        ]
    ), now: .preview)
}

#Preview("プレイヤーのタスク採用待ち") {
    let vision = Vision.preview(status: .active)
    PlayerTaskView(store: .preview(
        role: .player,
        visions: [vision],
        tasks: [
            .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .proposed),
            .preview(visionID: vision.id, title: "週3でジムに行く", status: .reported, reaction: .happy)
        ]
    ), now: .preview)
}

#Preview("プレイヤーのタスクなし") {
    PlayerTaskView(store: .preview(role: .player, visions: [.preview(status: .active)]), now: .preview)
}

#Preview("プレイヤーの催促") {
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
        now: .preview
    )
}
