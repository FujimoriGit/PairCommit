//
//  OnDeviceCriteriaReview.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import FoundationModels

public struct OnDeviceCriteriaReview: CriteriaReviewing {
    private let instructions: String
    private let prompt: @Sendable (_ statement: String, _ doneCriteria: String) -> String

    /// 端末上のモデルが使えないときは nil。
    public init?(
        instructions: String,
        prompt: @escaping @Sendable (_ statement: String, _ doneCriteria: String) -> String
    ) {
        guard Self.isAvailable else { return nil }
        self.instructions = instructions
        self.prompt = prompt
    }

    public func review(statement: String, doneCriteria: String) async throws(ReviewFailure) -> CriteriaReview {
        guard Self.isAvailable,
              #available(iOS 26.0, *) else { throw .unavailable }

        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(
                to: prompt(statement, doneCriteria),
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
    static var isAvailable: Bool {
        if #available(iOS 26.0, *) {
            SystemLanguageModel.default.isAvailable
        } else {
            false
        }
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
