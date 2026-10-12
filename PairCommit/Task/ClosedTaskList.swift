//
//  ClosedTaskList.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/06
//

import Application
import Domain
import SwiftUI

struct ClosedTaskList: View {
    let store: PartnershipStore
    let tasks: [TaskItem]
    let now: Date
    let onShowCancelled: () -> Void

    @ViewBuilder
    var body: some View {
        if !approved.isEmpty || !cancelled.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                TaskSectionHeader(title: String(localized: .taskListClosed), count: approved.count + cancelled.count)
                TaskRowGroup {
                    ForEach(approved) { task in
                        TaskRow(store: store, task: task, now: now)
                    }
                    if !cancelled.isEmpty {
                        Button(action: onShowCancelled) {
                            cancelledLink
                        }
                        .buttonStyle(.choice)
                    }
                }
            }
        }
    }
}

// MARK: - Private

private extension ClosedTaskList {
    var approved: [TaskItem] {
        tasks.filter { $0.status == .approved }
    }

    var cancelled: [TaskItem] {
        tasks.filter { $0.status == .cancelled }
    }

    var cancelledLink: some View {
        HStack(spacing: 12) {
            Text(.cancelledTasksTitle)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(cancelled.count, format: .number)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .contentShape(.rect)
    }
}
