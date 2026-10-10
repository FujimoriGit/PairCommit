//
//  CancelledTaskView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import SwiftUI

struct CancelledTaskView: View {
    let store: PartnershipStore
    let vision: Vision

    @Environment(\.presentingFailure) private var presentingFailure

    var body: some View {
        Screen(role: store.role) {
            if tasks.isEmpty {
                Placeholder(symbol: "tray", title: String(localized: .cancelledTasksEmpty))
            }
            ForEach(tasks) { task in
                TaskSummaryRow(task: task) {
                    restoration(of: task)
                }
            }
        }
        .navigationTitle(.cancelledTasksTitle)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: tasks)
    }
}

// MARK: - Private

private extension CancelledTaskView {
    var tasks: [TaskItem] {
        store.state.tasks(for: vision.id).filter { $0.status == .cancelled }
    }

    @ViewBuilder
    func restoration(of task: TaskItem) -> some View {
        if store.role == .manager, let previous = task.cancelledFrom {
            Button(.cancelledTasksRestore(previous.label)) {
                restore(task)
            }
            .buttonStyle(.soft)
        }
    }

    func restore(_ task: TaskItem) {
        Task {
            do throws(PartnershipFailure) {
                try await store.perform { state, role throws(DomainError) in
                    try state.restoringTask(task.id, by: role)
                }
            } catch {
                presentingFailure?(error.message)
            }
        }
    }
}

#Preview("見届ける人の取り消したタスク") {
    let vision = Vision.preview(status: .active)
    NavigationStack {
        CancelledTaskView(
            store: .preview(
                role: .manager,
                visions: [vision],
                tasks: [
                    .preview(visionID: vision.id, title: "週3でジムに行く", status: .cancelled, cancelledFrom: .reported),
                    .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .cancelled, reaction: .uneasy, cancelledFrom: .proposed)
                ]
            ),
            vision: vision
        )
    }
}

#Preview("挑む人の取り消したタスク") {
    let vision = Vision.preview(status: .active)
    NavigationStack {
        CancelledTaskView(
            store: .preview(
                role: .player,
                visions: [vision],
                tasks: [
                    .preview(visionID: vision.id, title: "週3でジムに行く", status: .cancelled)
                ]
            ),
            vision: vision
        )
    }
}
