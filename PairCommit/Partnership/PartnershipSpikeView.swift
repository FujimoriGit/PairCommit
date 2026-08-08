//
//  PartnershipSpikeView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Prefire
import SwiftUI

struct PartnershipSpikeView: View {
    @State private var pairing = MultipeerPairing()

    var body: some View {
        VStack(spacing: 28) {
            Text("ペアリング検証")
                .font(.title2.bold())

            Text(pairing.phase.label)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button("オーナーで開始") { pairing.start(as: .owner) }
                Button("参加者で開始") { pairing.start(as: .participant) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(pairing.phase != .idle)

            if pairing.phase != .idle {
                Button("リセット") { pairing.reset() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

#Preview {
    PartnershipSpikeView()
        // VRT: 記録環境(Intel)とCI(Apple Silicon)のアンチエイリアス差を吸収する許容値。
        .snapshot(precision: 0.98, perceptualPrecision: 0.98)
}
