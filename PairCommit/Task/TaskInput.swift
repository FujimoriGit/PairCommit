//
//  TaskInput.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Foundation

struct TaskInput {
    var title = ""
    var deadline: Date?

    var isComplete: Bool { !title.isEmpty }
}
