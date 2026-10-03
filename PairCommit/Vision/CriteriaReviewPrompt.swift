//
//  CriteriaReviewPrompt.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Foundation

/// 達成基準の下読みで、端末上のモデルに渡す文。
enum CriteriaReviewPrompt {
    static let instructions = String(localized: """
        あなたは目標設定の相談相手です。渡された達成基準が、期日に第三者から見て
        達成できたかどうかを判定できる書き方になっているかを見てください。
        数値・期日・観測できる事実が入っていれば判定できます。
        「頑張る」「意識する」のような主観的な表現しかないものは判定できません。
        助言は日本語で、60字以内の1文にしてください。
        """)

    static func prompt(statement: String, doneCriteria: String) -> String {
        String(localized: "ビジョン: \(statement)\n達成基準: \(doneCriteria)", comment: "端末上のモデルに渡す入力で、画面には出ない。1つ目の %@ はビジョン、2つ目は達成基準")
    }
}
