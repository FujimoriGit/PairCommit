//
//  ReconnectingView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/19
//

import Prefire
import SwiftUI

struct ReconnectingView: View {
    let failureMessage: String?
    let onRetry: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Backdrop())
    }
}

// MARK: - Private

private extension ReconnectingView {
    @ViewBuilder
    var content: some View {
        if let failureMessage {
            VStack(spacing: 14) {
                Placeholder(
                    symbol: "wifi.exclamationmark",
                    title: String(localized: .reconnectingFailed),
                    message: failureMessage
                )
                Button(.commonRetry, action: onRetry)
                    .buttonStyle(.filled)
                Button(.reconnectingStartOver, role: .destructive, action: onStartOver)
                    .buttonStyle(.soft)
            }
        } else {
            ProgressView(.reconnectingProgress)
        }
    }
}

#Preview("前回の相手とつなぎ直し中") {
    ReconnectingView(failureMessage: nil, onRetry: {}, onStartOver: {})
        .prefireIgnored()
}

#Preview("前回の相手とつなぎ直せない") {
    ReconnectingView(failureMessage: "相手と同期できませんでした", onRetry: {}, onStartOver: {})
}
