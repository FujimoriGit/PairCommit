//
//  TaskRoadmap.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Application
import Domain
import SwiftUI

/// 期限のあるタスクを、期限の日付の順に縦の時間軸へ並べる。
struct TaskRoadmap: View {
    let store: PartnershipStore
    let vision: Vision
    let tasks: [TaskItem]
    let now: Date

    @ScaledMetric(relativeTo: .headline) private var dateWidth: CGFloat = 40

    var body: some View {
        if !scheduled.isEmpty || vision.deadline != nil {
            ForEach(months, id: \.start) { month in
                VStack(alignment: .leading, spacing: 10) {
                    Text(month.start, format: .dateTime.year().month())
                        .sectionTitle()
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 10) {
                        ForEach(month.marks) { mark in
                            row(of: mark)
                        }
                    }
                    .background(alignment: .leading) {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(width: 2)
                            .padding(.leading, dateWidth + Self.pinWidth / 2 - 1)
                    }
                }
            }
        }
        TaskSection(
            title: String(localized: .commonNoDeadline),
            tasks: tasks.filter { $0.deadline == nil && $0.status != .cancelled },
            store: store,
            now: now
        )
    }
}

// MARK: - Private

private extension TaskRoadmap {
    static let pinWidth: CGFloat = 30

    enum Mark: Identifiable {
        case task(TaskItem, Date)
        case today(Date)
        case visionDeadline(Date)

        var date: Date {
            switch self {
            case .task(_, let date), .today(let date), .visionDeadline(let date): date
            }
        }

        var id: String {
            switch self {
            case .task(let task, _): task.id.uuidString
            case .today: "today"
            case .visionDeadline: "visionDeadline"
            }
        }
    }

    struct Month {
        let start: Date
        let marks: [Mark]
    }

    var scheduled: [Mark] {
        tasks.compactMap { task in
            guard task.status != .cancelled, let deadline = task.deadline else { return nil }
            return .task(task, deadline)
        }
    }

    var months: [Month] {
        let calendar = Calendar.current
        let marks = (scheduled + [.today(now)] + (vision.deadline.map { [Mark.visionDeadline($0)] } ?? []))
            .sorted { $0.date < $1.date }
        let grouped = Dictionary(grouping: marks) { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
        return grouped.keys.sorted().map { .init(start: $0, marks: grouped[$0] ?? []) }
    }

    @ViewBuilder
    func row(of mark: Mark) -> some View {
        switch mark {
        case .task(let task, let deadline):
            HStack(spacing: 0) {
                date(of: deadline, isLate: isLate(task))
                    .frame(width: dateWidth, alignment: .trailing)
                pin(of: task)
                    .frame(width: Self.pinWidth)
                TaskRow(store: store, task: task, now: now, style: .timeline)
                    .rowCard()
            }
        case .today:
            HStack(spacing: 0) {
                Text(.taskDueToday)
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red, in: .capsule)
                    .frame(width: dateWidth + Self.pinWidth)
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 2)
                    .accessibilityHidden(true)
            }
        case .visionDeadline(let deadline):
            HStack(spacing: 12) {
                Image(systemName: "flag.fill")
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(.roadmapVisionDeadline)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Text(deadline.formatted(Date.FormatStyle.yearMonthDayTime))
                        .font(.caption.weight(.semibold))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(store.role.accent, in: .rect(cornerRadius: 18))
            .accessibilityElement(children: .combine)
        }
    }

    func date(of deadline: Date, isLate: Bool) -> some View {
        VStack(spacing: 0) {
            Text(deadline, format: .dateTime.day(.defaultDigits))
                .font(.system(.headline, design: .rounded, weight: .bold))
            Text(deadline, format: .dateTime.weekday(.abbreviated))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isLate ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
        }
        .foregroundStyle(isLate ? AnyShapeStyle(Color.red) : AnyShapeStyle(.primary))
        .accessibilityHidden(true)
    }

    func pin(of task: TaskItem) -> some View {
        Circle()
            .fill(pinFill(of: task))
            .overlay {
                Circle().strokeBorder(pinStroke(of: task), lineWidth: 2)
            }
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
    }

    func isLate(_ task: TaskItem) -> Bool {
        task.status == .todo && task.due(at: now, in: .current) == .overdue
    }

    func pinFill(of task: TaskItem) -> AnyShapeStyle {
        switch task.status {
        case .approved: AnyShapeStyle(Color.green)
        case .proposed, .reported: AnyShapeStyle(Color.orange)
        case .todo where isLate(task): AnyShapeStyle(Color.red)
        case .todo, .cancelled: AnyShapeStyle(Color(.systemBackground))
        }
    }

    func pinStroke(of task: TaskItem) -> AnyShapeStyle {
        switch task.status {
        case .todo where !isLate(task), .cancelled: AnyShapeStyle(.tertiary)
        default: pinFill(of: task)
        }
    }
}

#Preview("見届ける人のロードマップ") {
    NavigationStack {
        let vision = Vision.preview(status: .active, deadline: .preview(daysLater: 30))
        let tasks = [TaskItem].board(in: vision)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TaskRoadmap(
                    store: .preview(role: .manager, visions: [vision], tasks: tasks),
                    vision: vision,
                    tasks: tasks,
                    now: .preview
                )
            }
            .padding(.horizontal, 20)
        }
    }
}
