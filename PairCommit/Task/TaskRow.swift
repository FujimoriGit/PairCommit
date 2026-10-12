//
//  TaskRow.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Application
import Domain
import SwiftUI

struct TaskRow: View {
    enum Style {
        case list
        /// 期限の日付を行の外に出す並べ方。
        case timeline
    }

    let store: PartnershipStore
    let task: TaskItem
    let now: Date
    var style = Style.list

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                TaskDetailView(store: store, taskID: task.id, now: now)
            } label: {
                heading
            }
            .buttonStyle(.plain)
            if isMyTurn {
                action
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .background {
            task.reaction?.tint.opacity(0.14)
        }
    }
}

struct TaskRowGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Group(subviews: content) { rows in
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    if row.id != rows.first?.id {
                        Divider()
                            .padding(.leading, 14)
                    }
                    row
                }
            }
        }
        .rowCard()
    }
}

// MARK: - Private

private extension TaskRow {
    var isMyTurn: Bool {
        task.status.turn == store.role
    }

    var heading: some View {
        HStack(spacing: 12) {
            if style == .list {
                TaskStatusIcon(task: task)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(task.status.isOpen ? HierarchicalShapeStyle.primary : .secondary)
                    .lineLimit(1)
                meta
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let reaction = task.reaction {
                Text(reaction.emoji)
            }
            if !isMyTurn {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
    }

    var meta: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if task.status != .todo {
                Text(task.status.label)
                    .marker(task.status.tint)
            }
            switch style {
            case .list:
                DeadlineText(task: task, now: now)
            case .timeline:
                if task.status == .todo, task.due(at: now, in: .current) == .overdue {
                    Text(.taskDueOverdue)
                        .marker(Color.red)
                }
            }
            if let progress = task.progress, task.status.isOpen {
                Text(Double(progress) / 100, format: .percent)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    var action: some View {
        switch store.role {
        case .manager: ManagerTaskActions(store: store, task: task, layout: .compact)
        case .player: PlayerTaskActions(store: store, task: task, layout: .compact)
        }
    }
}
