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
    var layout = TaskActionLayout.full

    @ViewBuilder
    var body: some View {
        switch layout {
        case .full:
            VStack(spacing: 12) {
                if task.status.isOpen {
                    reactions
                }
                if task.status == .todo {
                    Button(.playerTaskReport, action: report)
                        .buttonStyle(.filled)
                }
            }
        case .compact:
            if task.status == .todo {
                Button(.taskRowReport, action: report)
                    .buttonStyle(.compact)
                    .accessibilityLabel(Text(.playerTaskReport))
            }
        }
    }
}

// MARK: - Private

private extension PlayerTaskActions {
    func report() {
        Task {
            let saved = await store.send { state, role throws(TaskReportError) in
                try state.reportingTask(task.id, by: role)
            }
            if saved {
                Haptic.success.play()
            }
        }
    }

    var reactions: some View {
        HStack(spacing: 8) {
            ForEach(Reaction.allCases, id: \.self) { reaction in
                Button {
                    Haptic.selection.play()
                    Task {
                        await store.send { state, role throws(ReactionError) in
                            try state.settingReaction(
                                task.reaction == reaction ? nil : reaction,
                                on: task.id,
                                by: role
                            )
                        }
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
}
