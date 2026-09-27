//
//  OnDeviceCriteriaReview.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import Foundation
import FoundationModels

struct OnDeviceCriteriaReview: CriteriaReviewing {
    static var isAvailable: Bool {
        if #available(iOS 26.0, *) {
            SystemLanguageModel.default.isAvailable
        } else {
            false
        }
    }

    func review(statement: String, doneCriteria: String) async throws(ReviewFailure) -> CriteriaReview {
        guard Self.isAvailable,
              #available(iOS 26.0, *) else { throw .unavailable }

        let session = LanguageModelSession(instructions: Self.instructions)
        do {
            let response = try await session.respond(
                to: String(localized: "ビジョン: \(statement)\n達成基準: \(doneCriteria)"),
                generating: Reviewed.self
            )
            return .init(isVerifiable: response.content.isVerifiable, advice: response.content.advice)
        } catch {
            throw .failed
        }
    }
}

// MARK: - Private

private extension OnDeviceCriteriaReview {
    static var instructions: String {
        String(localized: """
        あなたは目標設定の相談相手です。渡された達成基準が、期日に第三者から見て
        達成できたかどうかを判定できる書き方になっているかを見てください。
        数値・期日・観測できる事実が入っていれば判定できます。
        「頑張る」「意識する」のような主観的な表現しかないものは判定できません。
        助言は日本語で、60字以内の1文にしてください。
        """)
    }
}

@available(iOS 26.0, *)
@Generable
private struct Reviewed {
    @Guide(description: "true if a third party can confirm whether it was achieved")
    let isVerifiable: Bool

    @Guide(description: "One sentence of advice, in the language and length the instructions ask for")
    let advice: String
}
