//
//  InvitationView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import SwiftUI

struct InvitationView: View {
    let url: URL?
    let failureMessage: String?
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            SymbolBadge(symbol: "link")

            VStack(spacing: 10) {
                Text("リンクを送る")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(status)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(failureMessage ?? String(localized: "LINE やメッセージで、相手に招待リンクを送ってください。相手がリンクを開いたら、ペアができるまでこの画面を開いたままにしてください。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Spacer()
            VStack(spacing: 12) {
                if failureMessage != nil {
                    Button("もう一度試す", action: onRetry)
                        .buttonStyle(.filled)
                } else if let url {
                    ShareLink("招待リンクを送る", item: url)
                        .buttonStyle(.filled)
                }
                Button("やめる", action: onCancel)
                    .buttonStyle(.soft)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Backdrop())
    }
}

// MARK: - Private

private extension InvitationView {
    var status: String {
        if failureMessage != nil { return String(localized: "ペアリングできませんでした") }
        return url == nil ? String(localized: "招待リンクを用意しています…") : String(localized: "相手の参加を待っています…")
    }
}

#Preview("招待リンクの相手待ち") {
    InvitationView(
        url: URL(string: "https://www.icloud.com/share/example"),
        failureMessage: nil,
        onRetry: {},
        onCancel: {}
    )
}

#Preview("招待リンクの失敗") {
    InvitationView(url: nil, failureMessage: FailureReason.offline.message, onRetry: {}, onCancel: {})
}
