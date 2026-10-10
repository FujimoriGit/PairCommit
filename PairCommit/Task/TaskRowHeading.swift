//
//  TaskRowHeading.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import SwiftUI

struct TaskRowHeading: View {
    let task: TaskItem
    let now: Date
    let showsReaction: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(task.title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showsReaction, let reaction = task.reaction {
                    Text(reaction.emoji)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                DeadlineText(task: task, now: now)
                Spacer(minLength: 8)
                Text(task.status.label)
                    .marker(task.status.tint)
            }
        }
        .contentShape(.rect)
    }
}
