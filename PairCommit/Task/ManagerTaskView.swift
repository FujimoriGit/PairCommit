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

    @State private var title = ""
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Role.manager.label)
        }
    }
}

// MARK: - Private

private extension ManagerTaskView {
    @ViewBuilder
    var content: some View {
        if let vision = store.state.activeVision {
            Form {
                Section("ビジョン") {
                    Text(vision.statement)
                }
                creation
                taskList(store.state.tasks(for: vision.id))
                failureRow
            }
        } else {
            ContentUnavailableView(
                "進行中のビジョンがありません",
                systemImage: "flag",
                description: Text("ビジョンを承認するとタスクを作れます")
            )
        }
    }

    var creation: some View {
        Section("タスクを追加") {
            TextField("やること", text: $title)
            Button("追加する") {
                let entered = title
                perform { try $0.creatingTask(title: entered, by: store.role).state }
                title = ""
            }
            .disabled(title.isEmpty)
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
                if let reaction = task.reaction {
                    Text(reaction.emoji)
                }
                Text(task.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            actions(for: task)
        }
        .swipeActions {
            if task.status.isOpen {
                Button("取り消す", role: .destructive) {
                    perform { try $0.cancellingTask(task.id, by: store.role) }
                }
            }
        }
    }

    @ViewBuilder
    func actions(for task: TaskItem) -> some View {
        switch task.status {
        case .proposed:
            Button("採用する") {
                perform { try $0.adoptingTask(task.id, by: store.role) }
            }
            .buttonStyle(.borderless)
        case .reported:
            HStack(spacing: 16) {
                Button("承認する") {
                    perform { try $0.approvingTask(task.id, by: store.role) }
                }
                Button("差し戻す") {
                    perform { try $0.returningTask(task.id, by: store.role) }
                }
            }
            .buttonStyle(.borderless)
        case .todo, .approved, .cancelled:
            EmptyView()
        }
    }

    @ViewBuilder
    var failureRow: some View {
        if let failure {
            Section {
                Text(failure)
                    .foregroundStyle(.red)
            }
        }
    }

    func perform(_ transform: @escaping (PartnershipState) throws -> PartnershipState) {
        Task {
            do {
                try await store.perform(transform)
                failure = nil
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

#Preview("管理者のタスク採用待ち") {
    let vision = Vision.preview(status: .active)
    ManagerTaskView(store: .preview(
        role: .manager,
        visions: [vision],
        tasks: [
            .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .proposed),
            .preview(visionID: vision.id, title: "週3でジムに行く", status: .todo, createdBy: .manager)
        ]
    ))
}

#Preview("管理者のタスク承認待ち") {
    let vision = Vision.preview(status: .active)
    ManagerTaskView(store: .preview(
        role: .manager,
        visions: [vision],
        tasks: [
            .preview(visionID: vision.id, title: "週3でジムに行く", status: .reported, reaction: .happy),
            .preview(visionID: vision.id, title: "夜10時以降は食べない", status: .todo, reaction: .uneasy),
            .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .approved)
        ]
    ))
}

#Preview("管理者のタスクなし") {
    ManagerTaskView(store: .preview(role: .manager, visions: [.preview(status: .active)]))
}
