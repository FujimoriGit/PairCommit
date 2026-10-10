//
//  TaskSummaryRow.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/06
//

import Domain
import SwiftUI

struct TaskSummaryRow: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            TaskDetailText(task: task)
        }
        .card(tinted: task.reaction?.tint)
    }
}
