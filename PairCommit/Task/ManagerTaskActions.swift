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

    @State private var isConfirmingCancel = false

    @Environment(\.presentingFailure) private var presentingFailure
    @Environment(\.playingFeedback) private var playingFeedback

    var body: some View {
        buttons
            .confirmationDialog(.managerTaskCancelConfirmationTitle, isPresented: $isConfirmingCancel) {
                Button(.managerTaskCancelTask, role: .destructive) {
                    playingFeedback?(.warning)
                    perform { state, role throws(DomainError) in try state.cancellingTask(task.id, by: role) }
                }
            } message: {
                Text(.managerTaskCancelConfirmationMessage)
            }
    }
}

// MARK: - Private

private extension ManagerTaskActions {
    @ViewBuilder
    var buttons: some View {
        switch task.status {
        case .proposed:
            VStack(spacing: 10) {
                Button(.managerTaskAccept) {
                    perform { state, role throws(DomainError) in try state.adoptingTask(task.id, by: role) }
                }
                .buttonStyle(.filled)
                cancellation
            }
        case .reported:
            VStack(spacing: 10) {
                Button(.commonApprove) {
                    perform { state, role throws(DomainError) in try state.approvingTask(task.id, by: role) }
                }
                .buttonStyle(.filled)
                HStack(spacing: 10) {
                    Button(.managerTaskSendBack) {
                        perform { state, role throws(DomainError) in try state.returningTask(task.id, by: role) }
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

    var cancellation: some View {
        Button(.managerTaskCancelTask, role: .destructive) {
            isConfirmingCancel = true
        }
        .buttonStyle(.soft(feedback: .impact(weight: .light)))
    }

    func perform(_ transform: @escaping @Sendable (PartnershipState, Role) throws(DomainError) -> PartnershipState) {
        Task {
            do throws(PartnershipFailure) {
                try await store.perform(transform)
            } catch {
                presentingFailure?(error.message)
            }
        }
    }
}
