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
    let partnerRole: Role?
    let failureMessage: String?
    let isCreatingLink: Bool
    let isCancelling: Bool
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            SymbolBadge(symbol: "link")
                .symbolEffect(.pulse, isActive: failureMessage == nil && !isCancelling)

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
                } else if let url, let partnerRole {
                    ShareLink(
                        item: url,
                        subject: Text(.invitationPreviewTitle),
                        message: Text(.invitationMessage(partnerRole.label)),
                        preview: SharePreview(String(localized: .invitationPreviewTitle))
                    ) {
                        Text(.invitationShare)
                    }
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
        partnerRole: .player,
        failureMessage: nil,
        isCreatingLink: false,
        isCancelling: false,
        onRetry: {},
        onCancel: {}
    )
    // 動いている途中を撮ると、撮るたびに画像が変わる
    .symbolEffectsRemoved()
}

#Preview("招待リンクの失敗") {
    InvitationView(
        url: nil,
        partnerRole: .player,
        failureMessage: PairingFailure.offline.message,
        isCreatingLink: true,
        isCancelling: false,
        onRetry: {},
        onCancel: {}
    )
}

#Preview("招待をやめている途中") {
    InvitationView(
        url: nil,
        partnerRole: .player,
        failureMessage: nil,
        isCreatingLink: false,
        isCancelling: true,
        onRetry: {},
        onCancel: {}
    )
}
