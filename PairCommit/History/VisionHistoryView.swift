//
//  VisionHistoryView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/05
//

import Domain
import SwiftUI

struct VisionHistoryView: View {
    let vision: Vision
    let outcome: Vision.Outcome
    let tasks: [TaskItem]
    let role: Role

    var body: some View {
        Screen(role: role) {
            VisionDetail(vision: vision, note: outcome.result, noteTint: outcome.tint)
            SectionHeader(text: "タスク")
            taskList
        }
        .navigationTitle("記録")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Private

private extension VisionHistoryView {
    @ViewBuilder
    var taskList: some View {
        if tasks.isEmpty {
            Placeholder(
                symbol: "checklist",
                title: "タスクはありませんでした",
                message: "このビジョンにタスクは作られませんでした"
            )
        } else {
            ForEach(tasks) { task in
                row(task)
            }
        }
    }

    func row(_ task: TaskItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(task.title)
                .font(.system(.body, design: .rounded, weight: .semibold))
            Spacer(minLength: 8)
            if let reaction = task.reaction {
                Text(reaction.emoji)
            }
            Text(task.status.label)
                .marker(task.status.tint)
        }
        .card(tinted: task.reaction?.tint)
    }
}

#Preview("記録のビジョン") {
    let vision = Vision.preview(status: .achieved, deadline: .preview(daysLater: -10))
    NavigationStack {
        VisionHistoryView(vision: vision, outcome: .achieved, tasks: [
            .preview(visionID: vision.id, title: "毎日30分歩く", status: .approved, reaction: .happy),
            .preview(visionID: vision.id, title: "間食をやめる", status: .cancelled, reaction: .angry),
            .preview(visionID: vision.id, title: "体重を記録する", status: .approved)
        ], role: .manager)
    }
}
