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
        if let failureMessage {
            ContentUnavailableView {
                Label("相手とつながりませんでした", systemImage: "wifi.exclamationmark")
            } description: {
                Text(failureMessage)
            } actions: {
                Button("もう一度試す", action: onRetry)
                    .buttonStyle(.borderedProminent)
                Button("役割の選択からやり直す", role: .destructive, action: onStartOver)
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
