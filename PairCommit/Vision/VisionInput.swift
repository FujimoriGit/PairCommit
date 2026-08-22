//
//  VisionInput.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Foundation

struct VisionInput {
    var statement = ""
    var doneCriteria = ""
    var deadline: Date?

    var isComplete: Bool { !statement.isEmpty && !doneCriteria.isEmpty }
}
