//
//  CriteriaReviewing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

public protocol CriteriaReviewing: Sendable {
    /// 起案されたビジョンの達成基準に、第三者が達成を確認できるだけの具体性があるかを見る。
    func review(statement: String, doneCriteria: String) async throws(ReviewFailure) -> CriteriaReview
}

public struct CriteriaReview: Equatable, Sendable {
    public let isVerifiable: Bool
    public let advice: String

    public init(isVerifiable: Bool, advice: String) {
        self.isVerifiable = isVerifiable
        self.advice = advice
    }
}

public enum ReviewFailure: Error, Equatable, Sendable {
    case unavailable
    case failed
}
