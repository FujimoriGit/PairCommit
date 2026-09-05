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

    var body: some View {
        content
            .navigationTitle("2人の記録")
    }
}

// MARK: - Private

private extension PartnershipHistoryView {
    @ViewBuilder
    var content: some View {
        if state.closedVisions.isEmpty {
            ContentUnavailableView(
                "まだ記録がありません",
                systemImage: "clock.arrow.circlepath",
                description: Text("ビジョンを閉じるとここに残ります")
            )
        } else {
            List(state.closedVisions) { vision in
                NavigationLink {
                    VisionHistoryView(vision: vision, tasks: state.tasks(for: vision.id))
                } label: {
                    row(vision)
                }
            }
        }
    }

    func row(_ vision: Vision) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vision.statement)
                .font(.headline)
            HStack(spacing: 8) {
                if let outcome = vision.outcome {
                    Text(outcome.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DeadlineText(deadline: vision.deadline)
            }
        }
    }
}

#Preview("記録の一覧") {
    NavigationStack {
        PartnershipHistoryView(state: PartnershipState(visions: [
            .preview(status: .achieved, deadline: .preview(daysLater: -10), createdAt: .preview(daysLater: -40)),
            .preview(
                statement: "毎朝6時に起きて出社前に1時間勉強する",
                status: .abandoned,
                createdAt: .preview(daysLater: -160)
            )
        ]))
    }
}

#Preview("記録なし") {
    NavigationStack {
        PartnershipHistoryView(state: PartnershipState())
    }
}
