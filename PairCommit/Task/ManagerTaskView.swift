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
        Screen(role: store.role, title: "タスク") {
            content
        }
        .partnershipReset()
        .partnershipHistoryLink()
        .toolbar {
            if store.state.activeVision != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    judgement
                }
            }
        }
        .confirmationDialog(
            "このビジョンを閉じますか",
            isPresented: confirming,
            presenting: outcome
        ) { outcome in
            Button(outcome.confirmation, role: .destructive) {
                close(as: outcome)
            }
        } message: { _ in
            Text("進行中のタスクはすべて取り消されます")
        }
    }
}

// MARK: - Private

private extension ManagerTaskView {
    @ViewBuilder
    var content: some View {
        if let vision = store.state.activeVision {
            let tasks = store.state.tasks(for: vision.id)
            VisionCard(vision: vision, role: store.role, now: now)
            NudgeCard(nudges: store.state.nudges(for: store.role, now: now), state: store.state)
            judgementList(tasks.filter(needsJudgement))
            taskList(tasks.filter { !needsJudgement($0) })
            creation
            FailureNote(message: failureMessage)
        } else {
            Placeholder(
                symbol: "flag",
                title: "進行中のビジョンがありません",
                message: "ビジョンを承認するとタスクを作れます"
            )
        }
    }

    @ViewBuilder
    func judgementList(_ tasks: [TaskItem]) -> some View {
        if !tasks.isEmpty {
            SectionHeader(text: "判断が要る")
            ForEach(tasks) { task in
                row(task)
            }
        }
    }

    @ViewBuilder
    func taskList(_ tasks: [TaskItem]) -> some View {
        SectionHeader(text: "タスク")
        if tasks.isEmpty {
            Placeholder(
                symbol: "checklist",
                title: "まだタスクがありません",
                message: "やることを追加すると、ここに並びます"
            )
        } else {
            ForEach(tasks) { task in
                row(task)
            }
        }
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
                DeadlineText(deadline: task.deadline, now: now)
                Chip(text: task.status.label, tint: task.status.tint)
            }
            actions(for: task)
        }
        .card(tinted: task.reaction?.tint)
    }

    @ViewBuilder
    func actions(for task: TaskItem) -> some View {
        switch task.status {
        case .proposed:
            VStack(spacing: 10) {
                Button("採用する") {
                    perform { state throws(DomainError) in try state.adoptingTask(task.id, by: store.role) }
                }
                .buttonStyle(.filled)
                cancellation(of: task)
            }
        case .reported:
            VStack(spacing: 10) {
                Button("承認する") {
                    perform { state throws(DomainError) in try state.approvingTask(task.id, by: store.role) }
                }
                .buttonStyle(.filled)
                HStack(spacing: 10) {
                    Button("差し戻す") {
                        perform { state throws(DomainError) in try state.returningTask(task.id, by: store.role) }
                    }
                    .buttonStyle(.soft(.destructive))
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
        Button("取り消す") {
            perform { state throws(DomainError) in try state.cancellingTask(task.id, by: store.role) }
        }
        .buttonStyle(.soft(.destructive))
    }

    var creation: some View {
        Panel(title: "タスクを追加") {
            TextField("やること", text: $input.title)
                .fieldBox()
            DeadlineField(deadline: $input.deadline)
            Button("追加する", action: create)
                .buttonStyle(.filled)
                .disabled(!input.isComplete)
        }
    }

    var judgement: some View {
        Menu("達成判断", systemImage: "flag.checkered") {
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

    func close(as outcome: Vision.Outcome) {
        guard let vision = store.state.activeVision else { return }
        perform { state throws(DomainError) in try state.closingVision(vision.id, as: outcome, by: store.role) }
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

#Preview("管理者のタスク採用待ち") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        ManagerTaskView(store: .preview(
            role: .manager,
            visions: [vision],
            tasks: [
                .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .proposed),
                .preview(visionID: vision.id, title: "週3でジムに行く", status: .todo, createdBy: .manager)
            ]
        ), now: .preview)
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
        ), now: .preview)
    }
}

#Preview("管理者のタスクなし") {
    NavigationStack {
        ManagerTaskView(store: .preview(role: .manager, visions: [.preview(status: .active)]), now: .preview)
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
            now: .preview
        )
    }
}
