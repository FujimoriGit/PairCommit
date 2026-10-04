//
//  InvitationView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import SwiftUI

struct InvitationView: View {
    let url: URL?
    let failureMessage: String?
    let isCreatingLink: Bool
    let isCancelling: Bool
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            SymbolBadge(symbol: "link")

            VStack(spacing: 10) {
                Text(.invitationTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(status)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if !isCancelling {
                    Text(failureMessage ?? String(localized: .invitationInstructions))
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
                } else if let url {
                    ShareLink(.invitationShare, item: url)
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

private extension InvitationView {
    var status: String {
        if isCancelling { return String(localized: .invitationCancelling) }
        if failureMessage != nil {
            return isCreatingLink ? String(localized: .invitationFailed) : String(localized: .commonPairingFailed)
        }
        return url == nil ? String(localized: .invitationPreparing) : String(localized: .invitationWaiting)
    }
}

#Preview("招待リンクの相手待ち") {
    InvitationView(
        url: URL(string: "https://www.icloud.com/share/example"),
        failureMessage: nil,
        isCreatingLink: false,
        isCancelling: false,
        onRetry: {},
        onCancel: {}
    )
}

#Preview("招待リンクの失敗") {
    InvitationView(
        url: nil,
        failureMessage: PairingFailure.offline.message,
        isCreatingLink: true,
        isCancelling: false,
        onRetry: {},
        onCancel: {}
    )
}

#Preview("招待をやめている途中") {
    InvitationView(url: nil, failureMessage: nil, isCreatingLink: false, isCancelling: true, onRetry: {}, onCancel: {})
}
