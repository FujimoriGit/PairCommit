//
//  PairingView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Prefire
import SwiftUI

struct PairingView: View {
    let phase: MultipeerPairing.Phase
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Text("相手と繋ぐ")
                .font(.title2.bold())

            Text(phase.label)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("2台を近くに置いたまま待ってください。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("やめる", action: onCancel)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview("ペアリングの相手待ち") {
    PairingView(phase: .searching, onCancel: {})
        // VRT: 記録環境(Intel)とCI(Apple Silicon)のアンチエイリアス差を吸収する許容値。
        .snapshot(precision: 0.98, perceptualPrecision: 0.98)
}
