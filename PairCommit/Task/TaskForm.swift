//
//  TaskForm.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/06
//

import Domain
import SwiftUI

struct TaskForm: View {
    let title: LocalizedStringResource
    let submitLabel: LocalizedStringResource
    let role: Role
    let now: Date
    /// 失敗したときは、画面に出す文を返す。
    let onSubmit: @MainActor (TaskInput) async -> String?

    @State private var input = TaskInput()
    @State private var failureMessage: String?
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Screen(role: role) {
                Panel {
                    TextField(String(localized: .taskFormTitlePlaceholder), text: $input.title)
                        .fieldBox()
                    TextField(String(localized: .taskFormDetailPlaceholder), text: $input.detail, axis: .vertical)
                        .lineLimit(2...4)
                        .fieldBox()
                    DeadlineField(deadline: $input.deadline, now: now)
                }
                Button(submitLabel, action: submit)
                    .buttonStyle(.filled)
                    .disabled(!input.isComplete || isSubmitting)
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

private extension TaskForm {
    func submit() {
        let entered = input
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

#Preview("タスクの追加フォーム") {
    TaskForm(title: .managerTaskCreationTitle, submitLabel: .managerTaskAdd, role: .manager, now: .preview) { _ in nil }
}
