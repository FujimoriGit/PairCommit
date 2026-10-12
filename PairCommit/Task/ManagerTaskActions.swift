//
//  ManagerTaskActions.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import SwiftUI

struct ManagerTaskActions: View {
    let store: PartnershipStore
    let task: TaskItem
    var layout = TaskActionLayout.full

    @State private var isConfirmingCancel = false
    @State private var review: TaskReview?

    var body: some View {
        buttons
            .confirmationDialog(.managerTaskCancelConfirmationTitle, isPresented: $isConfirmingCancel) {
                Button(.managerTaskCancelTask, role: .destructive) {
                    Haptic.warning.play()
                    send { state, role throws(TaskCancellationError) in try state.cancellingTask(task.id, by: role) }
                }
            } message: {
                Text(.managerTaskCancelConfirmationMessage)
            }
            .sheet(item: $review) { review in
                TaskReviewForm(review: review, taskTitle: task.title, role: store.role) { await submit(review, feedback: $0) }
            }
    }
}

// MARK: - Private

private extension ManagerTaskActions {
    @ViewBuilder
    var buttons: some View {
        switch layout {
        case .full: fullButtons
        case .compact: compactButton
        }
    }

    @ViewBuilder
    var compactButton: some View {
        switch task.status {
        case .proposed:
            Button(.taskRowAdopt, action: adopt)
                .buttonStyle(.compact)
                .accessibilityLabel(Text(.managerTaskAccept))
        case .reported:
            Button(.taskRowApprove) {
                review = .approval
            }
            .buttonStyle(.compact)
            .accessibilityLabel(Text(.commonApprove))
        case .todo, .approved, .cancelled:
            EmptyView()
        }
    }

    @ViewBuilder
    var fullButtons: some View {
        switch task.status {
        case .proposed:
            VStack(spacing: 10) {
                Button(.managerTaskAccept, action: adopt)
                    .buttonStyle(.filled)
                cancellation
            }
        case .reported:
            VStack(spacing: 10) {
                Button(.commonApprove) {
                    review = .approval
                }
                .buttonStyle(.filled)
                HStack(spacing: 10) {
                    Button(.managerTaskSendBack) {
                        review = .sendingBack
                    }
                    .buttonStyle(.soft(feedback: .warning))
                    cancellation
                }
            }
        case .todo:
            cancellation
        case .approved, .cancelled:
            EmptyView()
        }
    }

    func adopt() {
        send { state, role throws(TaskAdoptionError) in try state.adoptingTask(task.id, by: role) }
    }

    var cancellation: some View {
        Button(.managerTaskCancelTask, role: .destructive) {
            isConfirmingCancel = true
        }
        .buttonStyle(.soft(feedback: .lightImpact))
    }

    func submit(_ review: TaskReview, feedback: String) async -> String? {
        switch review {
        case .approval:
            await failureMessage { state, role throws(TaskApprovalError) in
                try state.approvingTask(task.id, feedback: feedback, by: role)
            }
        case .sendingBack:
            await failureMessage { state, role throws(TaskReturnError) in
                try state.returningTask(task.id, feedback: feedback, by: role)
            }
        }
    }

    func failureMessage<Rejection: PresentableError>(
        performing transform: @escaping @Sendable (PartnershipState, Role) throws(Rejection) -> PartnershipState
    ) async -> String? {
        do throws(PartnershipFailure<Rejection>) {
            try await store.perform(transform)
            return nil
        } catch {
            return error.message
        }
    }

    func send<Rejection: Error>(
        _ transform: @escaping @Sendable (PartnershipState, Role) throws(Rejection) -> PartnershipState
    ) {
        Task { await store.send(transform) }
    }
}
