//
//  FeedbackCue.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import SwiftUI

/// 鳴らすたびに `playing(_:)` で次の値を作り、`sensoryFeedback(trigger:)` に渡す。
/// 同じ振動を続けて鳴らしても値が変わる。
struct FeedbackCue: Equatable {
    let feedback: SensoryFeedback?
    private let count: Int

    init() {
        feedback = nil
        count = 0
    }

    func playing(_ feedback: SensoryFeedback) -> Self {
        .init(feedback: feedback, count: count + 1)
    }
}

// MARK: - Private

private extension FeedbackCue {
    init(feedback: SensoryFeedback, count: Int) {
        self.feedback = feedback
        self.count = count
    }
}
