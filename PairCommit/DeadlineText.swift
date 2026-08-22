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
            Text(deadline, format: Date.FormatStyle.deadlineDay)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// 実行環境のロケールに任せると、基準画像が記録した環境に依存する。
private let japanese = Locale(identifier: "ja_JP")

extension Date.FormatStyle {
    static var deadlineDay: Self { .dateTime.month().day().locale(japanese) }
    static var deadlineFull: Self { .dateTime.year().month().day().locale(japanese) }
}
