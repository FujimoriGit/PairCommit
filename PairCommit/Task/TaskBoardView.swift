//
//  TaskBoardView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Application
import Domain
import SwiftUI

struct TaskBoardView: View {
    let store: PartnershipStore
    let vision: Vision?
    let now: Date

    @State private var mode = Mode.list
    @State private var isAddingTask = false
    @State private var isShowingCancelledTasks = false

    var body: some View {
        Screen(role: store.role) {
            if let vision {
                board(of: vision)
            } else {
                Placeholder(
                    symbol: "flag",
                    title: String(localized: .taskBoardNoVisionTitle),
                    message: String(localized: .taskBoardNoVisionMessage)
                )
            }
        }
        .animation(.default, value: store.state)
        .animation(.default, value: mode)
        .navigationTitle(.commonTasks)
        .toolbar {
            if vision != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingTask = true
                    } label: {
                        Label(creationTitle, systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingTask) {
            TaskForm(
                title: creationTitle,
                submitLabel: submitLabel,
                role: store.role,
                now: now,
                onSubmit: { await create($0) }
            )
        }
        .navigationDestination(isPresented: $isShowingCancelledTasks) {
            if let vision {
                CancelledTaskView(store: store, vision: vision)
            }
        }
    }
}

// MARK: - Private

private extension TaskBoardView {
    enum Mode: Hashable {
        case list
        case roadmap
    }

    var creationTitle: LocalizedStringResource {
        switch store.role {
        case .manager: .managerTaskCreationTitle
        case .player: .playerTaskProposalTitle
        }
    }

    var submitLabel: LocalizedStringResource {
        switch store.role {
        case .manager: .managerTaskAdd
        case .player: .commonPropose
        }
    }

    var emptyMessage: LocalizedStringResource {
        switch store.role {
        case .manager: .managerTaskEmptyMessage
        case .player: .playerTaskEmptyMessage
        }
    }

    @ViewBuilder
    func board(of vision: Vision) -> some View {
        let tasks = store.state.tasks(for: vision.id)
        Picker(selection: $mode) {
            Text(.taskBoardModeList).tag(Mode.list)
            Text(.taskBoardModeRoadmap).tag(Mode.roadmap)
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        if tasks.isEmpty {
            Placeholder(
                symbol: "checklist",
                title: String(localized: .taskListEmptyTitle),
                message: String(localized: emptyMessage)
            )
        } else {
            switch mode {
            case .list: list(of: tasks)
            case .roadmap: TaskRoadmap(store: store, vision: vision, tasks: tasks, now: now)
            }
        }
    }

    @ViewBuilder
    func list(of tasks: [TaskItem]) -> some View {
        let awaitingManager = tasks.filter { $0.status.turn == .manager }
        let todo = tasks.filter { $0.status == .todo }.sortedByDeadline()
        if store.role == .manager {
            TaskSection(title: String(localized: .managerTaskNeedsDecision), tasks: awaitingManager, store: store, now: now)
        }
        ForEach([TaskItem.Due.overdue, .today, .withinWeek, .later, .unscheduled], id: \.self) { due in
            TaskSection(
                title: due.label,
                isAlert: due == .overdue,
                tasks: todo.filter { $0.due(at: now, in: .current) == due },
                store: store,
                now: now
            )
        }
        if store.role == .player {
            TaskSection(
                title: String(localized: .taskBoardPartnerTurn(Role.manager.label)),
                tasks: awaitingManager,
                store: store,
                now: now
            )
        }
        ClosedTaskList(store: store, tasks: tasks, now: now) { isShowingCancelledTasks = true }
    }

    func create(_ entered: TaskInput) async -> String? {
        do throws(PartnershipFailure<TaskCreationError>) {
            try await store.perform { state, role throws(TaskCreationError) in
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

#Preview("見届ける人のタスク一覧") {
    NavigationStack {
        let vision = Vision.preview(status: .active, deadline: .preview(daysLater: 30))
        TaskBoardView(store: .preview(role: .manager, visions: [vision], tasks: .board(in: vision)), vision: vision, now: .preview)
    }
}

#Preview("挑む人のタスク一覧") {
    NavigationStack {
        let vision = Vision.preview(status: .active, deadline: .preview(daysLater: 30))
        TaskBoardView(store: .preview(role: .player, visions: [vision], tasks: .board(in: vision)), vision: vision, now: .preview)
    }
}

#Preview("タスクがないタスク一覧") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        TaskBoardView(store: .preview(role: .manager, visions: [vision]), vision: vision, now: .preview)
    }
}

#Preview("ビジョンがないタスク一覧") {
    NavigationStack {
        TaskBoardView(store: .preview(role: .player, visions: []), vision: nil, now: .preview)
    }
}
