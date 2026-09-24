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
    @State private var revising: Vision.ID?
    @State private var confirmingDiscard = false

    var body: some View {
        Screen(role: store.role) {
            content
        }
        .partnershipReset()
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
            summary(of: vision, note: "\(Role.manager.label)の承認待ち")
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
        Button("起案する", action: draft)
            .buttonStyle(.filled)
            .disabled(!input.isComplete)
        FailureNote(message: failureMessage)
    }

    @ViewBuilder
    func revisionForm(_ vision: Vision) -> some View {
        fields
        VStack(spacing: 10) {
            Button("書き直す") { revise(vision) }
                .buttonStyle(.filled)
                .disabled(!input.isComplete)
            Button("やめる") {
                revising = nil
                input = .init()
                review = nil
            }
            .buttonStyle(.soft)
        }
        FailureNote(message: failureMessage)
    }

    @ViewBuilder
    var fields: some View {
        Panel(title: "ビジョン") {
            TextField("何を達成したいか", text: $input.statement, axis: .vertical)
                .lineLimit(2...4)
                .fieldBox()
        }
        Panel(title: "達成基準") {
            TextField("どうなれば達成か", text: $input.doneCriteria, axis: .vertical)
                .lineLimit(2...4)
                .fieldBox()
        }
        Panel(title: "動機") {
            TextField("なぜ達成したいか（任意）", text: $input.why, axis: .vertical)
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
            Panel(title: "達成基準の下読み") {
                Button("この基準で判定できるか見てもらう") {
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
            Button("\(Role.manager.label)に提出する") {
                perform { state throws(DomainError) in try state.proposingVision(vision.id, by: store.role) }
            }
            .buttonStyle(.filled)
            Button("書き直す") {
                input = .init(vision)
                review = nil
                revising = vision.id
            }
            .buttonStyle(.soft)
            Button("取り下げる", role: .destructive) {
                confirmingDiscard = true
            }
            .buttonStyle(.soft)
        }
        .confirmationDialog("このビジョンを取り下げますか", isPresented: $confirmingDiscard) {
            Button("取り下げる", role: .destructive) {
                perform { state throws(DomainError) in try state.discardingVision(vision.id, by: store.role) }
            }
        } message: {
            Text("書いた内容は消え、記録にも残りません。")
        }
        FailureNote(message: failureMessage)
    }

    @ViewBuilder
    func summary(of vision: Vision, note: String) -> some View {
        VisionDetail(vision: vision, note: note)
        FailureNote(message: failureMessage)
    }

    func draft() {
        let entered = input
        Task {
            do throws(PartnershipFailure) {
                try await store.perform { state throws(DomainError) in
                    try state.draftingVision(
                        statement: entered.statement,
                        doneCriteria: entered.doneCriteria,
                        deadline: entered.deadline,
                        why: entered.enteredWhy,
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

    func revise(_ vision: Vision) {
        let entered = input
        Task {
            do throws(PartnershipFailure) {
                try await store.perform { state throws(DomainError) in
                    try state.revisingVision(
                        vision.id,
                        statement: entered.statement,
                        doneCriteria: entered.doneCriteria,
                        deadline: entered.deadline,
                        why: entered.enteredWhy,
                        by: store.role
                    )
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
    NavigationStack {
        PlayerVisionView(store: .preview(role: .player, visions: []))
    }
}

#Preview("プレイヤーの提出待ち") {
    NavigationStack {
        PlayerVisionView(store: .preview(role: .player, visions: [.preview(status: .draft, deadline: .preview)]))
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
