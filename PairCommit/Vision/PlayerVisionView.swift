//
//  PlayerVisionView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Application
import Domain
import Infrastructure
import SwiftUI

struct PlayerVisionView: View {
    let store: PartnershipStore
    var reviewing: (any CriteriaReviewing)?

    @State private var input = VisionInput()
    @State private var review: CriteriaReview?
    @State private var failureMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Role.player.label)
                .partnershipReset()
                .partnershipHistory(store.state)
        }
    }
}

// MARK: - Private

private extension PlayerVisionView {
    var content: some View {
        Group {
            if let active = store.state.activeVision {
                summary(of: active, note: "進行中")
            } else if let proposed = store.state.visions.last(where: { $0.status == .proposed }) {
                summary(of: proposed, note: "管理者の承認を待っています")
            } else if let draft = store.state.visions.last(where: { $0.status == .draft }) {
                draftDetail(draft)
            } else {
                draftForm
            }
        }
    }

    var draftForm: some View {
        Form {
            if let achieved = store.state.lastAchievedVision {
                AchievementBanner(vision: achieved)
            }
            Section("ビジョン") {
                TextField("何を達成したいか", text: $input.statement, axis: .vertical)
            }
            Section("達成基準") {
                TextField("どうなれば達成か", text: $input.doneCriteria, axis: .vertical)
            }
            Section {
                DeadlineField(deadline: $input.deadline)
            }
            reviewSection
            Section {
                Button("起案する") {
                    let entered = input
                    Task {
                        do throws(PartnershipFailure) {
                            try await store.perform { state throws(DomainError) in
                                try state.draftingVision(
                                    statement: entered.statement,
                                    doneCriteria: entered.doneCriteria,
                                    deadline: entered.deadline,
                                    by: store.role
                                ).state
                            }
                            failureMessage = nil
                            input = .init()
                        } catch {
                            failureMessage = error.message
                        }
                    }
                }
                .disabled(!input.isComplete)
            }
            FailureRow(message: failureMessage)
        }
    }

    @ViewBuilder
    var reviewSection: some View {
        if let reviewing {
            Section("達成基準の下読み") {
                Button("この基準で判定できるか見てもらう") {
                    let entered = input
                    Task {
                        review = try? await reviewing.review(
                            statement: entered.statement,
                            doneCriteria: entered.doneCriteria
                        )
                    }
                }
                .disabled(!input.isComplete)

                if let review {
                    Label(
                        review.advice,
                        systemImage: review.isVerifiable ? "checkmark.circle" : "exclamationmark.triangle"
                    )
                    .foregroundStyle(review.isVerifiable ? .green : .orange)
                }
            }
        }
    }

    func draftDetail(_ vision: Vision) -> some View {
        Form {
            visionFields(vision)
            Section {
                Button("管理者に提出する") {
                    perform { state throws(DomainError) in try state.proposingVision(vision.id, by: store.role) }
                }
            }
            FailureRow(message: failureMessage)
        }
    }

    func summary(of vision: Vision, note: String) -> some View {
        Form {
            Section {
                Text(note)
                    .foregroundStyle(.secondary)
            }
            visionFields(vision)
            FailureRow(message: failureMessage)
        }
    }

    func visionFields(_ vision: Vision) -> some View {
        Section("ビジョン") {
            Text(vision.statement)
                .font(.headline)
            LabeledContent("達成基準", value: vision.doneCriteria)
            if let deadline = vision.deadline {
                LabeledContent("期限", value: deadline.formatted(Date.FormatStyle.yearMonthDay))
            }
        }
    }

    func perform(_ transform: @escaping @Sendable (PartnershipState) throws(DomainError) -> PartnershipState) {
        Task {
            do throws(PartnershipFailure) {
                try await store.perform(transform)
                failureMessage = nil
            } catch {
                failureMessage = error.message
            }
        }
    }
}

#Preview("プレイヤーの起案前") {
    PlayerVisionView(store: .preview(role: .player, visions: []))
}

#Preview("プレイヤーの提出待ち") {
    PlayerVisionView(store: .preview(role: .player, visions: [.preview(status: .draft, deadline: .preview)]))
}

#Preview("プレイヤーの承認待ち") {
    PlayerVisionView(store: .preview(role: .player, visions: [.preview(status: .proposed)]))
}

#Preview("プレイヤーの達成直後") {
    PlayerVisionView(store: .preview(role: .player, visions: [.preview(status: .achieved)]))
}

#Preview("プレイヤーの下読みつき起案") {
    PlayerVisionView(store: .preview(role: .player, visions: []), reviewing: PreviewCriteriaReview())
}
