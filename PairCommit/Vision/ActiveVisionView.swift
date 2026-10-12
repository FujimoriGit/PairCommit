//
//  ActiveVisionView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Application
import Domain
import SwiftUI

struct ActiveVisionView: View {
    let store: PartnershipStore
    let vision: Vision
    let now: Date

    @State private var outcome: Vision.Outcome?

    var body: some View {
        Screen(role: store.role) {
            Text(vision.statement)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .padding(.horizontal, 4)
            fields
            if store.role == .manager {
                judgement
            }
        }
        .navigationTitle(.commonVision)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            .managerTaskCloseVisionConfirmationTitle,
            isPresented: Binding(presenting: $outcome),
            presenting: outcome
        ) { outcome in
            Button(outcome.confirmation, role: .destructive) {
                (outcome == .achieved ? Haptic.impact : .warning).play()
                close(as: outcome)
            }
        } message: { _ in
            Text(.managerTaskCloseVisionConfirmationMessage)
        }
    }
}

// MARK: - Private

private extension ActiveVisionView {
    var fields: some View {
        Panel {
            field(String(localized: .commonDoneCriteria)) {
                Text(vision.doneCriteria)
            }
            if let why = vision.why {
                Divider()
                field(String(localized: .commonWhy)) {
                    Text(why)
                }
            }
            Divider()
            field(String(localized: .commonDeadline)) {
                Text(vision.remaining(at: now))
                if let elapsed = vision.elapsed(at: now) {
                    ProgressView(value: elapsed)
                }
            }
            let progress = store.state.progress(of: vision.id)
            if let summary = progress.summary, let fraction = progress.fraction {
                Divider()
                field(String(localized: .commonTasks)) {
                    Text(summary)
                    ProgressView(value: fraction)
                }
            }
        }
    }

    func field<Value: View>(_ title: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            value()
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    var judgement: some View {
        Panel(title: String(localized: .managerTaskJudgeOutcome)) {
            Text(.activeVisionJudgeNote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Vision.Outcome.allCases, id: \.self) { candidate in
                    Button(candidate.label, role: candidate == .abandoned ? .destructive : nil) {
                        outcome = candidate
                    }
                    .buttonStyle(.soft(feedback: .lightImpact))
                }
            }
        }
    }

    // ビジョンを閉じると、保存を待たずにこの画面ごと消える
    func close(as outcome: Vision.Outcome) {
        Task {
            let saved = await store.send { state, role throws(VisionClosingError) in
                try state.closingVision(vision.id, as: outcome, by: role)
            }
            if saved, outcome == .achieved {
                Haptic.success.play()
            }
        }
    }
}

#Preview("見届ける人のビジョンの詳細") {
    let vision = Vision.preview(
        status: .active,
        deadline: .preview(daysLater: 30),
        why: "次の健康診断で再検査を言い渡されたくない",
        createdAt: .preview(daysLater: -30)
    )
    NavigationStack {
        ActiveVisionView(
            store: .preview(
                role: .manager,
                visions: [vision],
                tasks: [
                    .preview(visionID: vision.id, title: "ジムに入会する", status: .approved),
                    .preview(visionID: vision.id, title: "週3でジムに行く", status: .todo)
                ]
            ),
            vision: vision,
            now: .preview
        )
    }
}

#Preview("挑む人のビジョンの詳細") {
    let vision = Vision.preview(status: .active)
    NavigationStack {
        ActiveVisionView(store: .preview(role: .player, visions: [vision]), vision: vision, now: .preview)
    }
}
