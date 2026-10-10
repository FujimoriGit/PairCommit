//
//  DeadlinePicker.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import SwiftUI

struct DeadlinePicker: View {
    let earliest: Date
    let onDecide: (Date) -> Void

    @State private var selection: Date
    @Environment(\.dismiss) private var dismiss

    init(selection: Date, now: Date, onDecide: @escaping (Date) -> Void) {
        earliest = min(selection, now)
        self.onDecide = onDecide
        _selection = .init(initialValue: selection)
    }

    var body: some View {
        NavigationStack {
            DatePicker(
                .commonDeadline,
                selection: $selection,
                in: earliest...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(.commonDeadline)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(.deadlinePickerDecide) {
                        onDecide(selection)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("期限のカレンダー") {
    DeadlinePicker(selection: .preview(daysLater: 7), now: .preview) { _ in }
}
