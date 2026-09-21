//
//  PartnershipHistoryView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/05
//

import Domain
import SwiftUI

struct PartnershipHistoryView: View {
    let state: PartnershipState
    let role: Role

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(Backdrop(colors: [role.accent]))
        .navigationTitle("2人の記録")
    }
}

// MARK: - Private

private extension PartnershipHistoryView {
    @ViewBuilder
    var content: some View {
        if state.closedVisions.isEmpty {
            Placeholder(
                symbol: "clock.arrow.circlepath",
                title: "まだ記録がありません",
                message: "ビジョンを閉じるとここに残ります"
            )
        } else {
            ForEach(state.closedVisions) { closed in
                NavigationLink {
                    VisionHistoryView(
                        vision: closed.vision,
                        outcome: closed.outcome,
                        tasks: state.tasks(for: closed.id),
                        role: role
                    )
                } label: {
                    row(closed)
                }
                .buttonStyle(.plain)
            }
        }
    }

    func row(_ closed: ClosedVision) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(closed.vision.statement)
                    .font(.system(.headline, design: .rounded))
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Text(closed.outcome.result)
                        .marker(closed.outcome.tint)
                    Text("\(closed.vision.createdAt.formatted(Date.FormatStyle.yearMonthDay))に起案")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .card()
    }
}

#Preview("記録の一覧") {
    NavigationStack {
        PartnershipHistoryView(state: PartnershipState(visions: [
            .preview(status: .achieved, createdAt: .preview(daysLater: -40)),
            .preview(
                statement: "毎朝6時に起きて出社前に1時間勉強する",
                status: .abandoned,
                createdAt: .preview(daysLater: -160)
            )
        ]), role: .manager)
    }
}

#Preview("記録なし") {
    NavigationStack {
        PartnershipHistoryView(state: PartnershipState(), role: .manager)
    }
}
