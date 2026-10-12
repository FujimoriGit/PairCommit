//
//  NudgeCard.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import Domain
import SwiftUI

struct NudgeCard: View {
    let state: PartnershipState
    let role: Role
    let now: Date
    let onOpenVision: () -> Void

    @ViewBuilder
    var body: some View {
        let nudges = state.nudges(for: role, now: now)
        if !nudges.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(nudges, id: \.self) { nudge in
                    if case .visionOverdue = nudge {
                        Button(action: onOpenVision) {
                            HStack(spacing: 8) {
                                label(of: nudge)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    } else {
                        label(of: nudge)
                    }
                }
            }
            .card()
        }
    }
}

// MARK: - Private

private extension NudgeCard {
    func label(of nudge: Nudge) -> some View {
        Label(nudge.message(in: state), systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
