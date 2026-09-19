//
//  VisionCard.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/19
//

import Domain
import SwiftUI

struct VisionCard: View {
    let vision: Vision
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vision.statement)
                .font(.headline)
                .lineLimit(2)
            Text(vision.doneCriteria)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Label(remaining, systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Private

private extension VisionCard {
    var remaining: String {
        guard let deadline = vision.deadline else { return "期限なし" }
        let date = deadline.formatted(Date.FormatStyle.yearMonthDay)
        return switch vision.countdown(at: now, in: .current) {
        case .unbounded: "期限なし"
        case .overdue: "\(date)の期限を過ぎています"
        case .days(0): "今日まで"
        case .days(let days): "残り\(days)日（\(date)まで）"
        }
    }
}

#Preview("ビジョンカードの期限あり") {
    VisionCard(vision: .preview(status: .active, deadline: .preview(daysLater: 30)), now: .preview)
}

#Preview("ビジョンカードの期限なし") {
    VisionCard(vision: .preview(status: .active), now: .preview)
}

#Preview("ビジョンカードの期限当日") {
    VisionCard(vision: .preview(status: .active, deadline: .preview), now: .preview)
}

#Preview("ビジョンカードの期限切れ") {
    VisionCard(vision: .preview(status: .active, deadline: .preview(daysLater: -3)), now: .preview)
}
