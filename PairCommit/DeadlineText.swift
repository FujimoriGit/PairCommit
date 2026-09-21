//
//  DeadlineText.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import SwiftUI

struct DeadlineText: View {
    let task: TaskItem
    var now = Date()

    @ViewBuilder
    var body: some View {
        if let deadline = task.deadline {
            Text(deadline.formatted(Date.FormatStyle.monthDay))
                .marker(isLate(deadline) ? Color(.deepRed) : .secondary)
        }
    }
}

// MARK: - Private

private extension DeadlineText {
    func isLate(_ deadline: Date) -> Bool {
        task.status == .todo && deadline < now
    }
}
