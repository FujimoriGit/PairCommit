//
//  ReviewForm.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Domain
import SwiftUI

struct ReviewForm: View {
    struct Wording {
        let title: LocalizedStringResource
        let placeholder: LocalizedStringResource
        let submitLabel: LocalizedStringResource
        let requiresFeedback: Bool
    }

    let wording: Wording
    let subject: String
    let role: Role
    /// 失敗したときは、画面に出す文を返す。
    let onSubmit: @MainActor (String) async -> String?

    @State private var feedback = ""
    @State private var failureMessage: String?
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Screen(role: role) {
                Panel(title: subject) {
                    TextField(String(localized: wording.placeholder), text: $feedback, axis: .vertical)
                        .lineLimit(3...6)
                        .fieldBox()
                }
                Button(wording.submitLabel, action: submit)
                    .buttonStyle(.filled)
                    .disabled((wording.requiresFeedback && feedback.isBlank) || isSubmitting)
                FailureNote(message: failureMessage)
            }
            .navigationTitle(wording.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.commonCancel) { dismiss() }
                }
            }
        }
        .animation(.default, value: failureMessage)
        .sensoryFeedback(.error, trigger: failureMessage) { _, message in message != nil }
    }
}

extension ReviewForm.Wording {
    static var taskApproval: Self {
        .init(
            title: .taskReviewApprovalTitle,
            placeholder: .taskReviewApprovalPlaceholder,
            submitLabel: .commonApprove,
            requiresFeedback: false
        )
    }

    static var taskSendingBack: Self {
        .init(
            title: .taskReviewSendBackTitle,
            placeholder: .taskReviewSendBackPlaceholder,
            submitLabel: .managerTaskSendBack,
            requiresFeedback: true
        )
    }

    static var visionSendingBack: Self {
        .init(
            title: .visionReviewSendBackTitle,
            placeholder: .visionReviewSendBackPlaceholder,
            submitLabel: .managerVisionSendBack,
            requiresFeedback: true
        )
    }
}

// MARK: - Private

private extension ReviewForm {
    func submit() {
        let entered = feedback
        failureMessage = nil
        isSubmitting = true
        Task {
            failureMessage = await onSubmit(entered)
            isSubmitting = false
            if failureMessage == nil {
                dismiss()
            }
        }
    }
}

#Preview("完了の承認フォーム") {
    ReviewForm(wording: .taskApproval, subject: "週3でジムに行く", role: .manager) { _ in nil }
}

#Preview("完了報告の差し戻しフォーム") {
    ReviewForm(wording: .taskSendingBack, subject: "週3でジムに行く", role: .manager) { _ in nil }
}

#Preview("ビジョンの差し戻しフォーム") {
    ReviewForm(wording: .visionSendingBack, subject: "半年で10kg痩せて健康診断オールA", role: .manager) { _ in nil }
}
