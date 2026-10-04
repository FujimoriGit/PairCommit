//
//  PlayerVisionView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Application
import Domain
import SwiftUI

struct PlayerVisionView: View {
    let store: PartnershipStore
    let reviewing: (any CriteriaReviewing)?

    @State private var input: VisionInput
    @State private var review: CriteriaReview?
    @State private var failureMessage: String?
    @State private var revising: Vision.ID?
    @State private var confirmingDiscard = false
    @Environment(\.playingFeedback) private var playingFeedback

    init(store: PartnershipStore, reviewing: (any CriteriaReviewing)? = nil, revising draft: Vision? = nil) {
        self.store = store
        self.reviewing = reviewing
        _input = State(initialValue: draft.map { VisionInput($0) } ?? .init())
        _revising = State(initialValue: draft?.id)
    }

    var body: some View {
        Screen(role: store.role) {
            content
        }
        .animation(.default, value: store.state)
        .animation(.default, value: revising)
        .animation(.default, value: failureMessage)
        .sensoryFeedback(.error, trigger: failureMessage) { _, message in message != nil }
        .partnershipSettingsLink()
        .partnershipHistoryLink()
    }
}

// MARK: - Private

private extension PlayerVisionView {
    enum Stage {
        case proposed(Vision)
        case draft(Vision)
        case blank
    }

    var stage: Stage {
        if let proposed = store.state.visions.last(where: { $0.status == .proposed }) {
            return .proposed(proposed)
        }
        if let draft = store.state.visions.last(where: { $0.status == .draft }) {
            return .draft(draft)
        }
        return .blank
    }

    @ViewBuilder
    var content: some View {
        switch stage {
        case .proposed(let vision):
            summary(of: vision, note: String(localized: .playerVisionAwaitingManager(Role.manager.label)))
        case .draft(let vision) where revising == vision.id:
            revisionForm(vision)
        case .draft(let vision):
            draftDetail(vision)
        case .blank:
            draftForm
        }
    }

    @ViewBuilder
    var draftForm: some View {
        if let achieved = store.state.lastAchievedVision {
            AchievementBanner(vision: achieved)
        }
        fields
        Button(.commonPropose, action: draft)
            .buttonStyle(.filled)
            .disabled(!input.isComplete)
        FailureNote(message: failureMessage)
    }

    @ViewBuilder
    func revisionForm(_ vision: Vision) -> some View {
        fields
        VStack(spacing: 10) {
            Button(.playerVisionRevise) { revise(vision) }
                .buttonStyle(.filled)
                .disabled(!input.isComplete)
            Button(.commonCancel) {
                revising = nil
                input = .init()
                review = nil
                failureMessage = nil
            }
            .buttonStyle(.soft)
        }
        FailureNote(message: failureMessage)
    }

    @ViewBuilder
    var fields: some View {
        Panel(title: String(localized: .commonVision)) {
            TextField(.visionFormStatementPlaceholder, text: $input.statement, axis: .vertical)
                .lineLimit(2...4)
                .fieldBox()
        }
        Panel(title: String(localized: .commonDoneCriteria)) {
            TextField(.visionFormDoneCriteriaPlaceholder, text: $input.doneCriteria, axis: .vertical)
                .lineLimit(2...4)
                .fieldBox()
        }
        Panel(title: String(localized: .commonWhy)) {
            TextField(.visionFormWhyPlaceholder, text: $input.why, axis: .vertical)
                .lineLimit(2...4)
                .fieldBox()
        }
        Panel {
            DeadlineField(deadline: $input.deadline)
        }
        reviewSection
    }

    @ViewBuilder
    var reviewSection: some View {
        if let reviewing {
            Panel(title: String(localized: .criteriaReviewTitle)) {
                Button(.criteriaReviewRequest) {
                    let entered = input
                    Task {
                        review = try? await reviewing.review(
                            statement: entered.statement,
                            doneCriteria: entered.doneCriteria
                        )
                    }
                }
                .buttonStyle(.soft)
                .disabled(!input.isComplete)

                if let review {
                    Label(
                        review.advice,
                        systemImage: review.isVerifiable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(review.isVerifiable ? .green : .orange)
                }
            }
        }
    }

    @ViewBuilder
    func draftDetail(_ vision: Vision) -> some View {
        VisionDetail(vision: vision)
        VStack(spacing: 10) {
            Button(.playerVisionSubmit(Role.manager.label)) {
                perform { state, role throws(DomainError) in try state.proposingVision(vision.id, by: role) }
            }
            .buttonStyle(.filled)
            Button(.playerVisionRevise) {
                input = .init(vision)
                review = nil
                failureMessage = nil
                revising = vision.id
            }
            .buttonStyle(.soft)
            Button(.playerVisionWithdraw, role: .destructive) {
                confirmingDiscard = true
            }
            .buttonStyle(.soft(feedback: .impact(weight: .light)))
        }
        .confirmationDialog(.playerVisionWithdrawConfirmationTitle, isPresented: $confirmingDiscard) {
            Button(.playerVisionWithdraw, role: .destructive) {
                playingFeedback?(.warning)
                perform { state, role throws(DomainError) in try state.discardingVision(vision.id, by: role) }
            }
        } message: {
            Text(.playerVisionWithdrawConfirmationMessage)
        }
        FailureNote(message: failureMessage)
    }

    @ViewBuilder
    func summary(of vision: Vision, note: String) -> some View {
        VisionDetail(vision: vision, note: note)
        FailureNote(message: failureMessage)
    }

    func draft() {
        let content = input.content
        failureMessage = nil
        Task {
            do throws(PartnershipFailure) {
                try await store.perform { state, role throws(DomainError) in
                    try state.draftingVision(content, by: role).state
                }
                failureMessage = nil
                input = .init()
                review = nil
            } catch {
                failureMessage = error.message
            }
        }
    }

    func revise(_ vision: Vision) {
        let content = input.content
        failureMessage = nil
        Task {
            do throws(PartnershipFailure) {
                try await store.perform { state, role throws(DomainError) in
                    try state.revisingVision(vision.id, to: content, by: role)
                }
                failureMessage = nil
                input = .init()
                review = nil
                revising = nil
            } catch {
                failureMessage = error.message
            }
        }
    }

    func perform(_ transform: @escaping @Sendable (PartnershipState, Role) throws(DomainError) -> PartnershipState) {
        failureMessage = nil
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
    NavigationStack {
        PlayerVisionView(store: .preview(role: .player, visions: []))
    }
}

#Preview("プレイヤーの提出待ち") {
    NavigationStack {
        PlayerVisionView(store: .preview(role: .player, visions: [.preview(status: .draft, deadline: .preview)]))
    }
}

#Preview("プレイヤーの書き直し") {
    let draft = Vision.preview(status: .draft, deadline: .preview, why: "次の健康診断で再検査を言い渡されたくない")
    NavigationStack {
        PlayerVisionView(store: .preview(role: .player, visions: [draft]), revising: draft)
    }
}

#Preview("プレイヤーの承認待ち") {
    NavigationStack {
        PlayerVisionView(store: .preview(role: .player, visions: [.preview(status: .proposed)]))
    }
}

#Preview("プレイヤーの達成直後") {
    NavigationStack {
        PlayerVisionView(store: .preview(role: .player, visions: [.preview(status: .achieved)]))
    }
}

#Preview("プレイヤーの下読みつき起案") {
    NavigationStack {
        PlayerVisionView(store: .preview(role: .player, visions: []), reviewing: PreviewCriteriaReview())
    }
}
