//
//  OnDeviceCriteriaReview.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import FoundationModels

struct OnDeviceCriteriaReview: CriteriaReviewing {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func review(statement: String, doneCriteria: String) async throws(ReviewFailure) -> CriteriaReview {
        guard Self.isAvailable else { throw .unavailable }

        let session = LanguageModelSession(instructions: Self.instructions)
        do {
            let response = try await session.respond(
                to: "ビジョン: \(statement)\n達成基準: \(doneCriteria)",
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
        """
        あなたは目標設定の相談相手です。渡された達成基準が、期日に第三者から見て
        達成できたかどうかを判定できる書き方になっているかを見てください。
        数値・期日・観測できる事実が入っていれば判定できます。
        「頑張る」「意識する」のような主観的な表現しかないものは判定できません。
        助言は日本語で、60字以内の1文にしてください。
        """
    }
}

@Generable
private struct Reviewed {
    @Guide(description: "達成できたかどうかを第三者が確認できる書き方なら true")
    let isVerifiable: Bool

    @Guide(description: "日本語60字以内の助言を1文")
    let advice: String
}
