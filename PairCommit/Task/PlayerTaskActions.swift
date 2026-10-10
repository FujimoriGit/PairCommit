//
//  PlayerTaskActions.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import SwiftUI

struct PlayerTaskActions: View {
    let store: PartnershipStore
    let task: TaskItem

    @Environment(\.presentingFailure) private var presentingFailure
    @Environment(\.playingFeedback) private var playingFeedback

    var body: some View {
        VStack(spacing: 12) {
            reactions
            if task.status == .todo {
                Button(.playerTaskReport) {
                    perform(succeeding: .success) { state, role throws(DomainError) in
                        try state.reportingTask(task.id, by: role)
                    }
                }
                .buttonStyle(.filled)
            }
        }
    }
}

// MARK: - Private

private extension PlayerTaskActions {
    var reactions: some View {
        HStack(spacing: 8) {
            ForEach(Reaction.allCases, id: \.self) { reaction in
                Button {
                    playingFeedback?(.selection)
                    perform { state, role throws(DomainError) in
                        try state.settingReaction(
                            task.reaction == reaction ? nil : reaction,
                            on: task.id,
                            by: role
                        )
                    }
                } label: {
                    label(of: reaction, chosen: task.reaction == reaction)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(task.reaction == reaction ? .isSelected : [])
            }
        }
    }

    func label(of reaction: Reaction, chosen: Bool) -> some View {
        Text(reaction.emoji)
            .font(.title3)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                chosen ? reaction.tint.opacity(0.22) : Color(.tertiarySystemFill),
                in: .rect(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(reaction.tint, lineWidth: chosen ? 2 : 0)
            }
            .contentShape(.rect)
    }

    func perform(
        succeeding success: SensoryFeedback? = nil,
        _ transform: @escaping @Sendable (PartnershipState, Role) throws(DomainError) -> PartnershipState
    ) {
        Task {
            do throws(PartnershipFailure) {
                try await store.perform(transform)
                if let success {
                    playingFeedback?(success)
                }
            } catch {
                presentingFailure?(error.message)
            }
        }
    }
}
