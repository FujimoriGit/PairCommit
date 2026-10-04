//
//  PairingMethodView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import SwiftUI

struct PairingMethodView: View {
    let role: Role
    let onNearby: () -> Void
    let onRemote: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button(action: onNearby) {
                    ChoiceCard(
                        symbol: "dot.radiowaves.left.and.right",
                        title: String(localized: .pairingMethodNearbyTitle),
                        summary: String(localized: .pairingMethodNearbySummary),
                        accent: role.accent
                    )
                }
                .buttonStyle(.choice)

                Button(action: onRemote) {
                    ChoiceCard(
                        symbol: "link",
                        title: String(localized: .pairingMethodRemoteTitle),
                        summary: String(localized: .pairingMethodRemoteSummary),
                        accent: role.accent
                    )
                }
                .buttonStyle(.choice)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(Backdrop())
        .navigationTitle(.pairingMethodTitle)
    }
}

#Preview("ペアリング方法の選択") {
    NavigationStack {
        PairingMethodView(role: .manager, onNearby: {}, onRemote: {})
    }
}
