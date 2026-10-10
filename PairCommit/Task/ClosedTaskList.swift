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
    let vision: Vision

    @State private var isShowingCancelled = false

    @ViewBuilder
    var body: some View {
        if !approved.isEmpty || !cancelled.isEmpty {
            SectionHeader(text: String(localized: .taskListClosed))
            ForEach(approved) { task in
                TaskSummaryRow(task: task)
            }
            if !cancelled.isEmpty {
                Button {
                    isShowingCancelled = true
                } label: {
                    cancelledLink
                }
                .buttonStyle(.choice)
                .sheet(isPresented: $isShowingCancelled) {
                    CancelledTaskSheet(store: store, vision: vision)
                }
            }
        }
    }
}

// MARK: - Private

private extension ClosedTaskList {
    var tasks: [TaskItem] {
        store.state.tasks(for: vision.id)
    }

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
            Spacer(minLength: 8)
            Text(cancelled.count, format: .number)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .card()
    }
}
