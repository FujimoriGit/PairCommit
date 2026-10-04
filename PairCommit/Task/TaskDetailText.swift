//
//  TaskDetailText.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/04
//

import Domain
import SwiftUI

struct TaskDetailText: View {
    let task: TaskItem

    @ViewBuilder
    var body: some View {
        if let detail = task.detail {
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
