//
//  DeadlineField.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import SwiftUI

struct DeadlineField: View {
    @Binding var deadline: Date?
    let now: Date

    @State private var isPicking = false

    var body: some View {
        VStack(spacing: 10) {
            Toggle(.deadlineFieldToggle, isOn: decided)
                .font(.subheadline)
            if let deadline {
                LabeledContent {
                    Button(deadline.formatted(Date.FormatStyle.yearMonthDayTime)) {
                        isPicking = true
                    }
                    .buttonStyle(.bordered)
                } label: {
                    Text(.commonDeadline)
                }
                .font(.subheadline)
                if deadline <= now {
                    Text(.deadlineFieldPassed)
                        .marker(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .sheet(isPresented: $isPicking) {
            DeadlinePicker(selection: deadline ?? now, now: now) { deadline = $0 }
        }
    }
}

// MARK: - Private

private extension DeadlineField {
    var decided: Binding<Bool> {
        .init(get: { deadline != nil }, set: { isOn in
            deadline = isOn ? Calendar.current.date(byAdding: .day, value: 7, to: now) : nil
        })
    }
}
