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

    @State private var isProposingTask = false
    @State private var isShowingCancelledTasks = false

    var body: some View {
        Screen(role: store.role) {
            PartnerLine(pairing: store.state.pairing, role: store.role)
            content
        }
        .animation(.default, value: store.state)
        .sheet(isPresented: $isProposingTask) {
            TaskForm(
                title: .playerTaskProposalTitle,
                submitLabel: .commonPropose,
                role: store.role,
                now: now,
                onSubmit: { await create($0) }
            )
        }
        .navigationDestination(isPresented: $isShowingCancelledTasks) {
            CancelledTaskView(store: store, vision: vision)
        }
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
        let tasks = store.state.tasks(for: vision.id)
        taskList(tasks)
        Button {
            isProposingTask = true
        } label: {
            Label(.playerTaskProposalTitle, systemImage: "plus")
        }
        .buttonStyle(.soft)
        ClosedTaskList(tasks: tasks) { isShowingCancelledTasks = true }
    }

    @ViewBuilder
    func taskList(_ tasks: [TaskItem]) -> some View {
        let open = tasks.filter(\.status.isOpen)
        if tasks.isEmpty {
            SectionHeader(text: String(localized: .commonTasks))
            Placeholder(
                symbol: "checklist",
                title: String(localized: .taskListEmptyTitle),
                message: String(localized: .playerTaskEmptyMessage)
            )
        } else if !open.isEmpty {
            SectionHeader(text: String(localized: .commonTasks))
            ForEach(open) { task in
                row(task)
            }
        }
    }

    func row(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                TaskDetailView(store: store, taskID: task.id, now: now)
            } label: {
                TaskRowHeading(task: task, now: now, showsReaction: false)
            }
            .buttonStyle(.plain)
            TaskDetailText(task: task)
            if let progress = task.progress {
                TaskProgressBar(percent: progress)
            }
            PlayerTaskActions(store: store, task: task)
        }
        .card(tinted: task.reaction?.tint)
    }

    func create(_ entered: TaskInput) async -> String? {
        do throws(PartnershipFailure) {
            try await store.perform { state, role throws(DomainError) in
                try state.creatingTask(
                    title: entered.title,
                    detail: entered.detail,
                    deadline: entered.deadline,
                    by: role
                ).state
            }
            return nil
        } catch {
            return error.message
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
