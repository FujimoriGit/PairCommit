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

    @ViewBuilder
    var body: some View {
        let nudges = state.nudges(for: role, now: now)
        if !nudges.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(nudges, id: \.self) { nudge in
                    Label(nudge.message(in: state), systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
            .card()
        }
    }
}
