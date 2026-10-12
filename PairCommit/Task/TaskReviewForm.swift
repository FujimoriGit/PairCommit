//
//  TaskReviewForm.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Domain
import SwiftUI

enum TaskReview: Hashable, Identifiable {
    case approval
    case sendingBack

    var id: Self { self }
}

struct TaskReviewForm: View {
    let review: TaskReview
    let taskTitle: String
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
                Panel(title: taskTitle) {
                    TextField(String(localized: placeholder), text: $feedback, axis: .vertical)
                        .lineLimit(3...6)
                        .fieldBox()
                }
                Button(submitLabel, action: submit)
                    .buttonStyle(.filled)
                    .disabled((review == .sendingBack && feedback.isBlank) || isSubmitting)
                FailureNote(message: failureMessage)
            }
            .navigationTitle(title)
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

// MARK: - Private

private extension TaskReviewForm {
    var title: LocalizedStringResource {
        switch review {
        case .approval: .taskReviewApprovalTitle
        case .sendingBack: .taskReviewSendBackTitle
        }
    }

    var placeholder: LocalizedStringResource {
        switch review {
        case .approval: .taskReviewApprovalPlaceholder
        case .sendingBack: .taskReviewSendBackPlaceholder
        }
    }

    var submitLabel: LocalizedStringResource {
        switch review {
        case .approval: .commonApprove
        case .sendingBack: .managerTaskSendBack
        }
    }

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
    TaskReviewForm(review: .approval, taskTitle: "週3でジムに行く", role: .manager) { _ in nil }
}

#Preview("完了報告の差し戻しフォーム") {
    TaskReviewForm(review: .sendingBack, taskTitle: "週3でジムに行く", role: .manager) { _ in nil }
}
