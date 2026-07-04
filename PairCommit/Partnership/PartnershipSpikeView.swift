//
//  PartnershipSpikeView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import SwiftUI

/// Spike: 2台で動かして検証するための最小UI。
/// 片方で「オーナーで開始」、もう片方で「参加者で開始」を押す。
struct PartnershipSpikeView: View {
    @State private var service = PartnershipService()

    var body: some View {
        VStack(spacing: 28) {
            Text("ペアリング検証")
                .font(.title2.bold())

            Text(service.phase.label)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button("オーナーで開始") { service.start(as: .owner) }
                Button("参加者で開始") { service.start(as: .participant) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(service.phase != .idle)

            if service.phase != .idle {
                Button("リセット") { service.reset() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

#Preview {
    PartnershipSpikeView()
}
