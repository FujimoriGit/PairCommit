//
//  CriteriaReviewPrompt.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Foundation

/// 達成基準の下読みで、端末上のモデルに渡す文。
enum CriteriaReviewPrompt {
    static let instructions = String(localized: .criteriaReviewInstructions)

    static func prompt(statement: String, doneCriteria: String) -> String {
        String(localized: .criteriaReviewPrompt(statement, doneCriteria))
    }
}
