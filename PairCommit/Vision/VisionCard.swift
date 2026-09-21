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
    let role: Role
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ビジョン")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.75))
            Text(vision.statement)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(3)
            Text(vision.doneCriteria)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)
            countdown
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(role.accent.gradient, in: .rect(cornerRadius: 24))
        .shadow(color: role.accent.opacity(0.3), radius: 12, y: 6)
    }
}

// MARK: - Private

private extension VisionCard {
    var countdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(remaining, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            if let progress {
                bar(progress)
            }
        }
    }

    func bar(_ progress: Double) -> some View {
        Capsule()
            .fill(.white.opacity(0.25))
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.white)
                        .frame(width: proxy.size.width * progress)
                }
            }
    }

    var remaining: String {
        switch vision.countdown(at: now, in: .current) {
        case .unbounded: "期限なし"
        case .overdue(let deadline): "\(deadline.formatted(Date.FormatStyle.yearMonthDay))の期限を過ぎています"
        case .days(0, _): "今日まで"
        case .days(let days, let deadline): "残り\(days)日（\(deadline.formatted(Date.FormatStyle.yearMonthDay))まで）"
        }
    }

    var symbol: String {
        switch vision.countdown(at: now, in: .current) {
        case .unbounded: "infinity"
        case .overdue: "exclamationmark.triangle.fill"
        case .days: "calendar"
        }
    }

    var progress: Double? {
        switch vision.countdown(at: now, in: .current) {
        case .unbounded: nil
        case .overdue: 1
        case .days(_, let deadline): elapsed(until: deadline)
        }
    }

    func elapsed(until deadline: Date) -> Double? {
        let span = deadline.timeIntervalSince(vision.createdAt)
        guard span > 0 else { return nil }
        return min(max(now.timeIntervalSince(vision.createdAt) / span, 0), 1)
    }
}

#Preview("ビジョンカードの期限あり") {
    VisionCard(vision: .preview(status: .active, deadline: .preview(daysLater: 30)), role: .player, now: .preview)
        .padding()
}

#Preview("ビジョンカードの期限なし") {
    VisionCard(vision: .preview(status: .active), role: .player, now: .preview)
        .padding()
}

#Preview("ビジョンカードの期限当日") {
    VisionCard(vision: .preview(status: .active, deadline: .preview), role: .manager, now: .preview)
        .padding()
}

#Preview("ビジョンカードの長文") {
    VisionCard(
        vision: .preview(
            statement: "来年の春までに10kg痩せて、健康診断の全項目でA判定を取り、フルマラソンを完走する",
            doneCriteria: "体重68kg以下を4週続けて保ち、次回の健康診断で全項目A判定、春の大会で制限時間内に完走する",
            status: .active,
            deadline: .preview(daysLater: 30)
        ),
        role: .player,
        now: .preview
    )
    .padding()
}

#Preview("ビジョンカードの期限切れ") {
    VisionCard(vision: .preview(status: .active, deadline: .preview(daysLater: -3)), role: .manager, now: .preview)
        .padding()
}
