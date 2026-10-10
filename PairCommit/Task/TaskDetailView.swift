//
//  TaskDetailView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import SwiftUI

struct TaskDetailView: View {
    let store: PartnershipStore
    let taskID: TaskItem.ID
    let now: Date

    @State private var editingProgress: Double?

    @Environment(\.presentingFailure) private var presentingFailure

    var body: some View {
        Screen(role: store.role) {
            if let task {
                summary(of: task)
                progress(of: task)
                NoteSection(store: store, subject: .task(task.id))
            }
        }
        .navigationTitle(.taskDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: task)
        .sensoryFeedback(.selection, trigger: editingProgress) { _, value in value != nil }
    }
}

// MARK: - Private

private extension TaskDetailView {
    var task: TaskItem? {
        store.state.tasks.first { $0.id == taskID }
    }

    func summary(of task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(task.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer(minLength: 8)
                if let reaction = task.reaction {
                    Text(reaction.emoji)
                }
                Text(task.status.label)
                    .marker(task.status.tint)
            }
            DeadlineText(task: task, now: now)
            TaskDetailText(task: task)
        }
        .card(tinted: task.reaction?.tint)
    }

    @ViewBuilder
    func progress(of task: TaskItem) -> some View {
        if store.role == .manager, task.status == .todo || task.status == .reported {
            Panel {
                let current = editingProgress ?? Double(task.progress ?? 0)
                HStack(alignment: .firstTextBaseline) {
                    Text(.taskDetailProgress)
                        .sectionTitle()
                    Spacer(minLength: 8)
                    Text(current / 100, format: .percent)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: .init(get: { current }, set: { editingProgress = $0 }), in: 0...100, step: 10) {
                    Text(.taskDetailProgress)
                } onEditingChanged: { isEditing in
                    guard !isEditing, let value = editingProgress else { return }
                    setProgress(Int(value), on: task)
                }
                // VoiceOver の調整では、触って離すことがないので編集の終わりが届かない
                .accessibilityAdjustableAction { direction in
                    let step = direction == .increment ? 10 : -10
                    setProgress(min(max((task.progress ?? 0) + step, 0), 100), on: task)
                }
            }
        } else if let percent = task.progress {
            Panel(title: String(localized: .taskDetailProgress)) {
                TaskProgressBar(percent: percent)
            }
        }
    }

    func setProgress(_ percent: Int, on task: TaskItem) {
        guard percent != task.progress else {
            editingProgress = nil
            return
        }
        Task {
            defer { editingProgress = nil }
            do throws(PartnershipFailure) {
                try await store.perform { state, role throws(DomainError) in
                    try state.settingProgress(percent, on: task.id, by: role)
                }
            } catch {
                presentingFailure?(error.message)
            }
        }
    }
}

#Preview("見届ける人のタスクの詳細") {
    let vision = Vision.preview(status: .active)
    let task = TaskItem.preview(
        visionID: vision.id,
        title: "週3でジムに行く",
        detail: "筋トレ30分と有酸素20分。行けなかった週は土日に回す",
        status: .todo,
        createdBy: .manager,
        reaction: .happy,
        deadline: .preview(daysLater: 30),
        progress: 40
    )
    let notes = [
        Note.preview(on: .task(task.id), kind: .report, author: .player, number: 1, body: "今週は2回行けた。金曜に残りの1回を入れる"),
        Note.preview(on: .task(task.id), kind: .feedback, author: .manager, number: 2, body: "いいペース。金曜に行けたら教えて")
    ]
    NavigationStack {
        TaskDetailView(
            store: .preview(role: .manager, visions: [vision], tasks: [task], notes: notes),
            taskID: task.id,
            now: .preview
        )
    }
}

#Preview("挑む人のタスクの詳細") {
    let vision = Vision.preview(status: .active)
    let task = TaskItem.preview(
        visionID: vision.id,
        title: "週3でジムに行く",
        status: .reported,
        createdBy: .manager,
        progress: 80
    )
    let notes = [
        Note.preview(on: .task(task.id), kind: .reminder, author: .manager, number: 1, body: "そろそろ承認するから、どこまでやったか教えて")
    ]
    NavigationStack {
        TaskDetailView(
            store: .preview(role: .player, visions: [vision], tasks: [task], notes: notes),
            taskID: task.id,
            now: .preview
        )
    }
}
