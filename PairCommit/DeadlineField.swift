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

    var body: some View {
        VStack(spacing: 10) {
            Toggle(.deadlineFieldToggle, isOn: decided)
                .font(.subheadline)
            if let deadline {
                // 範囲の外の値は範囲の端に寄せて表示されるが、Binding には書き戻されない。
                DatePicker(
                    .commonDeadline,
                    selection: .init(get: { deadline }, set: { self.deadline = $0 }),
                    in: min(deadline, now)...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(.subheadline)
                if deadline <= now {
                    Text(.deadlineFieldPassed)
                        .marker(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
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
