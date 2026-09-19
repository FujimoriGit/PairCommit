//
//  DateFormatStyle.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/06
//

import Foundation

// Text(_:format:) はスタイルのロケールを環境のロケールで上書きするため、
// 文字列にしてから渡す。環境任せだと基準画像が記録した環境に依存する。
private let japanese = Locale(identifier: "ja_JP")

extension Date.FormatStyle {
    static var monthDay: Self { .dateTime.month().day().locale(japanese) }
    static var yearMonthDay: Self { .dateTime.year().month().day().locale(japanese) }
}
