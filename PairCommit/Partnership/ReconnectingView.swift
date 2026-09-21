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
                    title: "相手とつながりませんでした",
                    message: failureMessage
                )
                Button("もう一度試す", action: onRetry)
                    .buttonStyle(.filled)
                Button("役割の選択からやり直す", action: onStartOver)
                    .buttonStyle(.soft(.destructive))
            }
        } else {
            ProgressView("相手とつないでいます…")
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
