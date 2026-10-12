//
//  TaskStatusIcon.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Domain
import SwiftUI

struct TaskStatusIcon: View {
    let task: TaskItem

    var body: some View {
        symbol
            .frame(width: 24, height: 24)
            .accessibilityElement()
            .accessibilityLabel(task.status.label)
    }
}

// MARK: - Private

private extension TaskStatusIcon {
    @ViewBuilder
    var symbol: some View {
        switch task.status {
        case .proposed:
            Circle()
                .strokeBorder(.orange, style: StrokeStyle(lineWidth: 2, dash: [3.2, 2.8]))
        case .todo:
            Circle()
                .strokeBorder(.tertiary, lineWidth: 2)
                .overlay {
                    if let progress = task.progress, progress > 0 {
                        Circle()
                            .inset(by: 1.2)
                            .trim(from: 0, to: Double(progress) / 100)
                            .stroke(.tint, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                }
        case .reported:
            Circle()
                .strokeBorder(.orange, lineWidth: 2)
                .overlay {
                    HalfDisc()
                        .fill(.orange)
                        .padding(5.5)
                }
        case .approved:
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .foregroundStyle(.white, .green)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .foregroundStyle(.white, .secondary)
        }
    }
}

private struct HalfDisc: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .init(x: rect.midX, y: rect.minY))
            path.addArc(
                center: .init(x: rect.midX, y: rect.midY),
                radius: rect.width / 2,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.closeSubpath()
        }
    }
}
