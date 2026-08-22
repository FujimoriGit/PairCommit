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

    @State private var title = ""
    @State private var failure: String?

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
                Section("ビジョン") {
                    Text(vision.statement)
                }
                proposal
                taskList(store.state.tasks(for: vision.id))
                failureRow
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
            TextField("やること", text: $title)
            Button("起案する") {
                let entered = title
                perform { try $0.creatingTask(title: entered, by: store.role).state }
                title = ""
            }
            .buttonStyle(.borderedProminent)
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
                Text(task.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if task.status.isOpen {
                reactions(for: task)
            }
            if task.status == .todo {
                Button("完了を報告する") {
                    perform { try $0.reportingTask(task.id, by: store.role) }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    func reactions(for task: TaskItem) -> some View {
        HStack(spacing: 16) {
            ForEach(Reaction.allCases, id: \.self) { reaction in
                Button(reaction.emoji) {
                    perform {
                        try $0.settingReaction(
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

#Preview("プレイヤーのタスク報告前") {
    let vision = Vision.preview(status: .active)
    PlayerTaskView(store: .preview(
        role: .player,
        visions: [vision],
        tasks: [
            .preview(visionID: vision.id, title: "週3でジムに行く", status: .todo, createdBy: .manager),
            .preview(visionID: vision.id, title: "夜10時以降は食べない", status: .todo, createdBy: .manager, reaction: .angry)
        ]
    ))
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
    ))
}

#Preview("プレイヤーのタスクなし") {
    PlayerTaskView(store: .preview(role: .player, visions: [.preview(status: .active)]))
}
