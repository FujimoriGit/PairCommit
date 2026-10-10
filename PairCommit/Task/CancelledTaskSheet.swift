//
//  CancelledTaskSheet.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import SwiftUI

struct CancelledTaskSheet: View {
    let store: PartnershipStore
    let vision: Vision

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Screen(role: store.role) {
                ForEach(tasks) { task in
                    TaskSummaryRow(task: task)
                }
            }
            .navigationTitle(.cancelledTasksTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(.commonClose) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Private

private extension CancelledTaskSheet {
    var tasks: [TaskItem] {
        store.state.tasks(for: vision.id).filter { $0.status == .cancelled }
    }
}

#Preview("挑む人の取り消したタスク") {
    let vision = Vision.preview(status: .active)
    CancelledTaskSheet(
        store: .preview(
            role: .player,
            visions: [vision],
            tasks: [
                .preview(visionID: vision.id, title: "週3でジムに行く", status: .cancelled)
            ]
        ),
        vision: vision
    )
}
