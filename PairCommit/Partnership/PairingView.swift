//
//  PairingView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import SwiftUI

struct PairingView: View {
    let phase: MultipeerPairing.Phase
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tint)
                .frame(width: 96, height: 96)
                .background(Color(.secondarySystemGroupedBackground), in: .circle)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                .accessibilityHidden(true)

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
            Button(failure == nil ? "やめる" : "戻る", action: onCancel)
                .buttonStyle(.soft)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Backdrop())
    }
}

// MARK: - Private

private extension PairingView {
    var failure: FailureReason? {
        guard case .failed(let reason) = phase else { return nil }
        return reason
    }

    var note: String {
        failure?.message ?? "2台を近くに置いたまま待ってください。"
    }
}

#Preview("ペアリングの相手待ち") {
    PairingView(phase: .searching, onCancel: {})
}

#Preview("ペアリングの失敗") {
    PairingView(phase: .failed(.signedOutOfICloud), onCancel: {})
}
