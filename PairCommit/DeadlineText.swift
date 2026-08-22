//
//  DeadlineText.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import SwiftUI

struct DeadlineText: View {
    let deadline: Date?

    var body: some View {
        if let deadline {
            Text(deadline.formatted(Date.FormatStyle.deadlineDay))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// Text(_:format:) はスタイルのロケールを環境のロケールで上書きするため、
// 文字列にしてから渡す。環境任せだと基準画像が記録した環境に依存する。
private let japanese = Locale(identifier: "ja_JP")

extension Date.FormatStyle {
    static var deadlineDay: Self { .dateTime.month().day().locale(japanese) }
    static var deadlineFull: Self { .dateTime.year().month().day().locale(japanese) }
}
