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
    var now = Date()

    @State private var input = TaskInput()
    @State private var outcome: Vision.Outcome?
    @State private var failureMessage: String?

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
                nudgeSection
                Section("ビジョン") {
                    Text(vision.statement)
                }
                Section("達成基準") {
                    Text(vision.doneCriteria)
                }
                if let deadline = vision.deadline {
                    Section("期限") {
                        Text(deadline.formatted(Date.FormatStyle.deadlineFull))
                    }
                }
                creation
                taskList(store.state.tasks(for: vision.id))
                judgement
                FailureRow(message: failureMessage)
            }
            .confirmationDialog(
                "このビジョンを閉じますか",
                isPresented: confirming,
                presenting: outcome
            ) { outcome in
                Button(outcome.confirmation, role: .destructive) {
                    perform { state throws(DomainError) in try state.closingVision(vision.id, as: outcome, by: store.role) }
                }
            } message: { _ in
                Text("進行中のタスクはすべて取り消されます")
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
            TextField("やること", text: $input.title)
            DeadlineField(deadline: $input.deadline)
            Button("追加する") {
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

    var judgement: some View {
        Section("達成判断") {
            ForEach(Vision.Outcome.allCases, id: \.self) { candidate in
                Button(candidate.label, role: candidate == .abandoned ? .destructive : nil) {
                    outcome = candidate
                }
            }
        }
    }

    var confirming: Binding<Bool> {
        .init(get: { outcome != nil }, set: { presented in
            if !presented { outcome = nil }
        })
    }

    @ViewBuilder
    var nudgeSection: some View {
        let nudges = store.state.nudges(for: store.role, now: now)
        if !nudges.isEmpty {
            Section("催促") {
                ForEach(nudges, id: \.self) { nudge in
                    Text(nudge.message(in: store.state))
                        .foregroundStyle(.orange)
                }
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
                if let reaction = task.reaction {
                    Text(reaction.emoji)
                }
                DeadlineText(deadline: task.deadline)
                Text(task.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            actions(for: task)
        }
        .swipeActions {
            if task.status.isOpen {
                Button("取り消す", role: .destructive) {
                    perform { state throws(DomainError) in try state.cancellingTask(task.id, by: store.role) }
                }
            }
        }
    }

    @ViewBuilder
    func actions(for task: TaskItem) -> some View {
        switch task.status {
        case .proposed:
            Button("採用する") {
                perform { state throws(DomainError) in try state.adoptingTask(task.id, by: store.role) }
            }
            .buttonStyle(.borderless)
        case .reported:
            HStack(spacing: 16) {
                Button("承認する") {
                    perform { state throws(DomainError) in try state.approvingTask(task.id, by: store.role) }
                }
                Button("差し戻す") {
                    perform { state throws(DomainError) in try state.returningTask(task.id, by: store.role) }
                }
            }
            .buttonStyle(.borderless)
        case .todo, .approved, .cancelled:
            EmptyView()
        }
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
    let vision = Vision.preview(status: .active, deadline: .preview)
    ManagerTaskView(store: .preview(
        role: .manager,
        visions: [vision],
        tasks: [
            .preview(visionID: vision.id, title: "週3でジムに行く", status: .reported, reaction: .happy, deadline: .preview),
            .preview(visionID: vision.id, title: "夜10時以降は食べない", status: .todo, reaction: .uneasy),
            .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .approved)
        ]
    ))
}

#Preview("管理者のタスクなし") {
    ManagerTaskView(store: .preview(role: .manager, visions: [.preview(status: .active)]))
}

#Preview("管理者の催促") {
    let vision = Vision.preview(status: .active)
    ManagerTaskView(
        store: .preview(
            role: .manager,
            visions: [vision],
            tasks: [.preview(visionID: vision.id, title: "週3でジムに行く", status: .reported)]
        ),
        now: .preview(daysLater: 3)
    )
}
