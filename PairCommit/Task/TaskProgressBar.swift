//
//  TaskProgressBar.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import SwiftUI

struct TaskProgressBar: View {
    let percent: Int

    var body: some View {
        HStack(spacing: 10) {
            ProgressView(value: Double(percent), total: 100)
            Text(Double(percent) / 100, format: .percent)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
