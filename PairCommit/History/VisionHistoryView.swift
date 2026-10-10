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
            SectionHeader(text: String(localized: .commonTasks))
            taskList
        }
        .navigationTitle(.commonHistory)
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
                title: String(localized: .visionHistoryNoTasks)
            )
        } else {
            ForEach(tasks) { task in
                TaskSummaryRow(task: task)
            }
        }
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

#Preview("記録のビジョンのタスクの詳細") {
    let vision = Vision.preview(status: .achieved, deadline: .preview(daysLater: -10))
    NavigationStack {
        VisionHistoryView(vision: vision, outcome: .achieved, tasks: [
            .preview(
                visionID: vision.id,
                title: "毎日30分歩く",
                detail: "通勤で1駅手前で降りる。雨の日は家でステッパー",
                status: .approved,
                reaction: .happy
            ),
            .preview(visionID: vision.id, title: "体重を記録する", detail: "朝食の前に測る", status: .approved)
        ], role: .manager)
    }
}
