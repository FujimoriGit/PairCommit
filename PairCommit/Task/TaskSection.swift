//
//  TaskSection.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Application
import Domain
import SwiftUI

struct TaskSection: View {
    let title: String
    var isAlert = false
    let tasks: [TaskItem]
    let store: PartnershipStore
    let now: Date

    @ViewBuilder
    var body: some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                TaskSectionHeader(title: title, count: tasks.count, isAlert: isAlert)
                TaskRowGroup {
                    ForEach(tasks) { task in
                        TaskRow(store: store, task: task, now: now)
                    }
                }
            }
        }
    }
}

struct TaskSectionHeader: View {
    let title: String
    let count: Int
    var isAlert = false

    var body: some View {
        HStack(spacing: 6) {
            if isAlert {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
            Text(title)
                .foregroundStyle(isAlert ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
            Text(count, format: .number)
                .foregroundStyle(.tertiary)
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
