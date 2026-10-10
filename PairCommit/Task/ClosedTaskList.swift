//
//  ClosedTaskList.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/06
//

import Domain
import SwiftUI

struct ClosedTaskList: View {
    let tasks: [TaskItem]

    @ViewBuilder
    var body: some View {
        if !tasks.isEmpty {
            SectionHeader(text: String(localized: .taskListClosed))
            ForEach(tasks) { task in
                TaskSummaryRow(task: task)
            }
        }
    }
}
