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
                        title: "近くにいる相手と",
                        summary: "2台を近くに置いて、そのまま繋ぎます。",
                        accent: role.accent
                    )
                }
                .buttonStyle(.plain)

                Button(action: onRemote) {
                    ChoiceCard(
                        symbol: "link",
                        title: "離れている相手と",
                        summary: "招待リンクを送って、相手に開いてもらいます。",
                        accent: role.accent
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(Backdrop())
        .navigationTitle("ペアリング方法を選ぶ")
    }
}

#Preview("ペアリング方法の選択") {
    NavigationStack {
        PairingMethodView(role: .manager, onNearby: {}, onRemote: {})
    }
}
