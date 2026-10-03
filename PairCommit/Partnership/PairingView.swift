//
//  PairingView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Application
import Domain
import SwiftUI

struct PairingView: View {
    let phase: NearbyPairing.Phase
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            SymbolBadge(symbol: "dot.radiowaves.left.and.right")

            VStack(spacing: 10) {
                Text("相手と繋ぐ")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(phase.label)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Spacer()
            Button(failure == nil ? String(localized: "やめる") : String(localized: "戻る"), action: onCancel)
                .buttonStyle(.soft)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Backdrop())
    }
}

// MARK: - Private

private extension NearbyPairing.Phase {
    var label: String {
        switch self {
        case .idle:        return String(localized: "待機中")
        case .searching:   return String(localized: "相手を探しています…")
        case .connected:   return String(localized: "相手が見つかりました")
        case .sharing, .handedOver: return String(localized: "ペアを登録しています…")
        case .done:        return String(localized: "ペアリングできました 🎉")
        case .failed:      return String(localized: "ペアリングできませんでした")
        }
    }
}

private extension PairingView {
    var failure: NearbyPairing.Failure? {
        guard case .failed(let reason) = phase else { return nil }
        return reason
    }

    var note: String {
        failure?.message ?? String(localized: "2台を近くに置いたまま待ってください。")
    }
}

#Preview("ペアリングの相手待ち") {
    PairingView(phase: .searching, onCancel: {})
}

#Preview("ペアリングの失敗") {
    PairingView(phase: .failed(.external(.signedOut)), onCancel: {})
}
