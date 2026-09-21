//
//  DeadlineField.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import SwiftUI

struct DeadlineField: View {
    @Binding var deadline: Date?

    var body: some View {
        VStack(spacing: 10) {
            Toggle("期限を決める", isOn: decided)
                .font(.subheadline)
            if let deadline {
                HStack {
                    Text("期限")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DatePicker(
                        "期限",
                        selection: .init(get: { deadline }, set: { self.deadline = $0 }),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
            }
        }
    }
}

// MARK: - Private

private extension DeadlineField {
    var decided: Binding<Bool> {
        .init(get: { deadline != nil }, set: { isOn in
            deadline = isOn ? Calendar.current.date(byAdding: .day, value: 7, to: .now) : nil
        })
    }
}
