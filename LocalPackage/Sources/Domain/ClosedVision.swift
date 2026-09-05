//
//  ClosedVision.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/05
//

import Foundation

public struct ClosedVision: Identifiable, Sendable {
    public let vision: Vision
    public let outcome: Vision.Outcome

    public var id: Vision.ID { vision.id }

    init?(_ vision: Vision) {
        guard let outcome = vision.outcome else { return nil }
        self.vision = vision
        self.outcome = outcome
    }
}
