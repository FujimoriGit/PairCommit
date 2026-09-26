//
//  VisionInput.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import Foundation

struct VisionInput {
    var statement = ""
    var doneCriteria = ""
    var deadline: Date?
    var why = ""

    var isComplete: Bool { !statement.isBlank && !doneCriteria.isBlank }

    var content: Vision.Content {
        .init(statement: statement, doneCriteria: doneCriteria, deadline: deadline, why: why)
    }
}

extension VisionInput {
    init(_ vision: Vision) {
        self.init(
            statement: vision.statement,
            doneCriteria: vision.doneCriteria,
            deadline: vision.deadline,
            why: vision.why ?? ""
        )
    }
}
