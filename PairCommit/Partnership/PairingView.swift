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
                .symbolEffect(.variableColor.iterative, isActive: isWaiting)

            VStack(spacing: 10) {
                Text(.nearbyPairingTitle)
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
            Button(failure == nil ? .commonCancel : .commonBack, action: onCancel)
                .buttonStyle(.soft)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Backdrop())
        .animation(.default, value: phase)
        .sensoryFeedback(trigger: phase) { _, phase in
            switch phase {
            case .connected: .impact
            case .done: .success
            case .failed: .error
            case .idle, .searching, .sharing, .handedOver: nil
            }
        }
    }
}

// MARK: - Private

private extension NearbyPairing.Phase {
    var label: String {
        switch self {
        case .idle:        return String(localized: .nearbyPairingIdle)
        case .searching:   return String(localized: .nearbyPairingSearching)
        case .connected:   return String(localized: .nearbyPairingConnected)
        case .sharing, .handedOver: return String(localized: .nearbyPairingSharing)
        case .done:        return String(localized: .nearbyPairingDone)
        case .failed:      return String(localized: .commonPairingFailed)
        }
    }
}

private extension PairingView {
    var isWaiting: Bool {
        switch phase {
        case .searching, .connected, .sharing, .handedOver: true
        case .idle, .done, .failed: false
        }
    }

    var failure: NearbyPairing.Failure? {
        guard case .failed(let reason) = phase else { return nil }
        return reason
    }

    var note: String {
        failure?.message ?? String(localized: .nearbyPairingNote)
    }
}

#Preview("ペアリングの相手待ち") {
    PairingView(phase: .searching, onCancel: {})
        // 動いている途中を撮ると、撮るたびに画像が変わる
        .symbolEffectsRemoved()
}

#Preview("ペアリングの失敗") {
    PairingView(phase: .failed(.external(.signedOut)), onCancel: {})
}
