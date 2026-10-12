//
//  HomeView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Application
import Domain
import SwiftUI

/// 進行中のビジョンがあるときのホーム。自分が手を動かすタスクだけを出す。
struct HomeView: View {
    let store: PartnershipStore
    let vision: Vision
    let now: Date

    @State private var isShowingVision = false

    var body: some View {
        Screen(role: store.role) {
            PartnerLine(pairing: store.state.pairing, role: store.role)
            Button {
                isShowingVision = true
            } label: {
                VisionCard(
                    vision: vision,
                    taskProgress: store.state.progress(of: vision.id),
                    role: store.role,
                    now: now
                )
            }
            .buttonStyle(.choice)
            NudgeCard(state: store.state, role: store.role, now: now) { isShowingVision = true }
            sections
        }
        .animation(.default, value: store.state)
        .navigationDestination(isPresented: $isShowingVision) {
            ActiveVisionView(store: store, vision: vision, now: now)
        }
    }
}

// MARK: - Private

private extension HomeView {
    var tasks: [TaskItem] {
        store.state.tasks(for: vision.id)
    }

    var todo: [TaskItem] {
        tasks.filter { $0.status == .todo }.sortedByDeadline()
    }

    @ViewBuilder
    var sections: some View {
        switch store.role {
        case .manager: managerSections
        case .player: playerSections
        }
    }

    @ViewBuilder
    var managerSections: some View {
        let decisions = tasks.filter { $0.status.turn == .manager }
        let overdue = todo.filter { $0.due(at: now, in: .current) == .overdue }
        if decisions.isEmpty, overdue.isEmpty {
            idle
        } else {
            TaskSection(title: String(localized: .managerTaskNeedsDecision), tasks: decisions, store: store, now: now)
            TaskSection(title: String(localized: .homeOverdueTasks), isAlert: true, tasks: overdue, store: store, now: now)
        }
    }

    @ViewBuilder
    var playerSections: some View {
        let dues: [TaskItem.Due] = [.overdue, .today, .withinWeek]
        let soon = todo.filter { dues.contains($0.due(at: now, in: .current)) }
        if soon.isEmpty {
            idle
        } else {
            ForEach(dues, id: \.self) { due in
                TaskSection(
                    title: due.label,
                    isAlert: due == .overdue,
                    tasks: soon.filter { $0.due(at: now, in: .current) == due },
                    store: store,
                    now: now
                )
            }
        }
    }

    var idle: some View {
        Placeholder(
            symbol: "checkmark.circle",
            title: String(localized: .homeIdleTitle),
            message: String(localized: .homeIdleMessage)
        )
    }
}

#Preview("見届ける人のホーム") {
    NavigationStack {
        let vision = Vision.preview(status: .active, deadline: .preview(daysLater: 30), createdAt: .preview(daysLater: -30))
        HomeView(
            store: .preview(
                role: .manager,
                visions: [vision],
                tasks: [
                    .preview(
                        visionID: vision.id,
                        title: "週3でジムに行く",
                        status: .reported,
                        reaction: .happy,
                        statusChangedAt: .preview(daysLater: -3)
                    ),
                    .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .proposed),
                    .preview(
                        visionID: vision.id,
                        title: "夜10時以降は食べない",
                        status: .todo,
                        createdBy: .manager,
                        reaction: .angry,
                        deadline: .preview(daysLater: -3),
                        progress: 40
                    ),
                    .preview(
                        visionID: vision.id,
                        title: "血液検査の予約を取る",
                        status: .todo,
                        createdBy: .manager,
                        deadline: .preview(daysLater: 5)
                    )
                ]
            ),
            vision: vision,
            now: .preview
        )
    }
}

#Preview("見届ける人のやることがないホーム") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        HomeView(
            store: .preview(
                role: .manager,
                visions: [vision],
                tasks: [.preview(visionID: vision.id, title: "週3でジムに行く", status: .todo, createdBy: .manager)]
            ),
            vision: vision,
            now: .preview
        )
    }
}

#Preview("見届ける人のビジョンの期限切れ") {
    NavigationStack {
        let vision = Vision.preview(status: .active, deadline: .preview(daysLater: -1), createdAt: .preview(daysLater: -30))
        HomeView(store: .preview(role: .manager, visions: [vision]), vision: vision, now: .preview)
    }
}

#Preview("挑む人のホーム") {
    NavigationStack {
        let vision = Vision.preview(status: .active, deadline: .preview(daysLater: 30), createdAt: .preview(daysLater: -30))
        HomeView(
            store: .preview(
                role: .player,
                visions: [vision],
                tasks: [
                    .preview(
                        visionID: vision.id,
                        title: "夜10時以降は食べない",
                        status: .todo,
                        createdBy: .manager,
                        reaction: .angry,
                        deadline: .preview(daysLater: -1),
                        progress: 40
                    ),
                    .preview(
                        visionID: vision.id,
                        title: "週末の献立を決める",
                        status: .todo,
                        createdBy: .manager,
                        deadline: .preview.addingTimeInterval(3 * 60 * 60)
                    ),
                    .preview(
                        visionID: vision.id,
                        title: "間食をナッツに置き換える",
                        status: .todo,
                        reaction: .uneasy,
                        deadline: .preview(daysLater: 3),
                        progress: 70
                    ),
                    .preview(visionID: vision.id, title: "5kmを30分で走る", status: .todo, deadline: .preview(daysLater: 20)),
                    .preview(visionID: vision.id, title: "週3でジムに行く", status: .reported)
                ]
            ),
            vision: vision,
            now: .preview
        )
    }
}

#Preview("挑む人のやることがないホーム") {
    NavigationStack {
        let vision = Vision.preview(status: .active)
        HomeView(
            store: .preview(
                role: .player,
                visions: [vision],
                tasks: [.preview(visionID: vision.id, title: "週3でジムに行く", status: .reported)]
            ),
            vision: vision,
            now: .preview
        )
    }
}
