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
    let tasks: [TaskItem]

    var body: some View {
        Form {
            visionSection
            taskSection
        }
        .navigationTitle("記録")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Private

private extension VisionHistoryView {
    var visionSection: some View {
        Section("ビジョン") {
            Text(vision.statement)
                .font(.headline)
            if let outcome = vision.outcome {
                LabeledContent("結果", value: outcome.result)
            }
            LabeledContent("達成基準", value: vision.doneCriteria)
            if let why = vision.why {
                LabeledContent("動機", value: why)
            }
            if let deadline = vision.deadline {
                LabeledContent("期限", value: deadline.formatted(Date.FormatStyle.deadlineFull))
            }
        }
    }

    @ViewBuilder
    var taskSection: some View {
        Section("タスク") {
            if tasks.isEmpty {
                Text("タスクはありませんでした")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    row(task)
                }
            }
        }
    }

    func row(_ task: TaskItem) -> some View {
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
        .listRowBackground(task.reaction.map { $0.tint.opacity(0.15) })
    }
}

#Preview("記録のビジョン") {
    let vision = Vision.preview(status: .achieved, deadline: .preview(daysLater: -10))
    NavigationStack {
        VisionHistoryView(vision: vision, tasks: [
            .preview(visionID: vision.id, title: "毎日30分歩く", status: .approved, reaction: .happy),
            .preview(visionID: vision.id, title: "間食をやめる", status: .cancelled, reaction: .angry),
            .preview(visionID: vision.id, title: "体重を記録する", status: .approved)
        ])
    }
}
