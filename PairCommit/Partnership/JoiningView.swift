//
//  JoiningView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/06
//

import Domain
import SwiftUI

struct JoiningView: View {
    let failureMessage: String?
    let isCancelling: Bool
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            SymbolBadge(symbol: "link")
                .symbolEffect(.pulse, isActive: failureMessage == nil && !isCancelling)

            VStack(spacing: 10) {
                Text(.joiningTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(status)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if !isCancelling {
                    Text(failureMessage ?? String(localized: .joiningInstructions))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)

            Spacer()
            VStack(spacing: 12) {
                if failureMessage != nil {
                    Button(.commonRetry, action: onRetry)
                        .buttonStyle(.filled)
                }
                Button(.commonCancel, action: onCancel)
                    .buttonStyle(.soft)
            }
            .disabled(isCancelling)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Backdrop())
    }
}

// MARK: - Private

private extension JoiningView {
    var status: String {
        if isCancelling { return String(localized: .joiningCancelling) }
        if failureMessage != nil { return String(localized: .commonPairingFailed) }
        return String(localized: .joiningWaiting)
    }
}

#Preview("招待リンクで参加して相手待ち") {
    JoiningView(failureMessage: nil, isCancelling: false, onRetry: {}, onCancel: {})
        // 動いている途中を撮ると、撮るたびに画像が変わる
        .symbolEffectsRemoved()
}

#Preview("招待リンクで参加できない") {
    JoiningView(failureMessage: PairingFailure.invitationWithdrawn.message, isCancelling: false, onRetry: {}, onCancel: {})
}
