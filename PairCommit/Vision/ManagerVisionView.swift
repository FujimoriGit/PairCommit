//
//  ManagerVisionView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Application
import Domain
import SwiftUI

struct ManagerVisionView: View {
    let store: PartnershipStore

    @State private var failure: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Role.manager.label)
        }
    }
}

// MARK: - Private

private extension ManagerVisionView {
    var content: some View {
        Group {
            if let active = store.state.activeVision {
                summary(of: active, note: "進行中")
            } else if let proposed = store.state.visions.last(where: { $0.status == .proposed }) {
                review(proposed)
            } else {
                waiting
            }
        }
    }

    var waiting: some View {
        ContentUnavailableView(
            "承認待ちのビジョンはありません",
            systemImage: "tray",
            description: Text("プレイヤーの起案を待っています")
        )
    }

    func review(_ vision: Vision) -> some View {
        Form {
            visionFields(vision)
            Section {
                Button("承認する") {
                    perform { try $0.approvingVision(vision.id, by: store.role) }
                }
                Button("起案者に差し戻す") {
                    perform { try $0.rejectingVision(vision.id, by: store.role) }
                }
            }
            failureRow
        }
    }

    func summary(of vision: Vision, note: String) -> some View {
        Form {
            Section {
                Text(note)
                    .foregroundStyle(.secondary)
            }
            visionFields(vision)
            failureRow
        }
    }

    func visionFields(_ vision: Vision) -> some View {
        Group {
            Section("ビジョン") {
                Text(vision.statement)
            }
            Section("達成基準") {
                Text(vision.doneCriteria)
            }
        }
    }

    @ViewBuilder
    var failureRow: some View {
        if let failure {
            Section {
                Text(failure)
                    .foregroundStyle(.red)
            }
        }
    }

    func perform(_ transform: @escaping (PartnershipState) throws -> PartnershipState) {
        Task {
            do {
                try await store.perform(transform)
                failure = nil
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

#Preview("起案待ち") {
    ManagerVisionView(store: .preview(role: .manager, visions: []))
}

#Preview("承認待ち") {
    ManagerVisionView(store: .preview(role: .manager, visions: [.preview(status: .proposed)]))
}

#Preview("進行中") {
    ManagerVisionView(store: .preview(role: .manager, visions: [.preview(status: .active)]))
}
