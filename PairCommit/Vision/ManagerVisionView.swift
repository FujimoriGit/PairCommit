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

    @State private var failureMessage: String?

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

    @ViewBuilder
    var waiting: some View {
        if let achieved = store.state.lastAchievedVision {
            ContentUnavailableView(
                "🎉 達成しました",
                systemImage: "flag.checkered",
                description: Text("\(achieved.statement)\n\nプレイヤーの次の起案を待っています")
            )
        } else {
            ContentUnavailableView(
                "承認待ちのビジョンはありません",
                systemImage: "tray",
                description: Text("プレイヤーの起案を待っています")
            )
        }
    }

    func review(_ vision: Vision) -> some View {
        Form {
            visionFields(vision)
            Section {
                Button("承認する") {
                    perform { state throws(DomainError) in try state.approvingVision(vision.id, by: store.role) }
                }
                Button("起案者に差し戻す") {
                    perform { state throws(DomainError) in try state.rejectingVision(vision.id, by: store.role) }
                }
            }
            FailureRow(message: failureMessage)
        }
    }

    func summary(of vision: Vision, note: String) -> some View {
        Form {
            Section {
                Text(note)
                    .foregroundStyle(.secondary)
            }
            visionFields(vision)
            FailureRow(message: failureMessage)
        }
    }

    func visionFields(_ vision: Vision) -> some View {
        Section("ビジョン") {
            Text(vision.statement)
                .font(.headline)
            LabeledContent("達成基準", value: vision.doneCriteria)
            if let deadline = vision.deadline {
                LabeledContent("期限", value: deadline.formatted(Date.FormatStyle.deadlineFull))
            }
        }
    }

    func perform(_ transform: @escaping (PartnershipState) throws(DomainError) -> PartnershipState) {
        Task {
            do throws(PartnershipFailure) {
                try await store.perform(transform)
                failureMessage = nil
            } catch {
                failureMessage = error.message
            }
        }
    }
}

#Preview("管理者の起案待ち") {
    ManagerVisionView(store: .preview(role: .manager, visions: []))
}

#Preview("管理者の承認待ち") {
    ManagerVisionView(store: .preview(role: .manager, visions: [.preview(status: .proposed, deadline: .preview)]))
}

#Preview("管理者の進行中") {
    ManagerVisionView(store: .preview(role: .manager, visions: [.preview(status: .active)]))
}

#Preview("管理者の達成直後") {
    ManagerVisionView(store: .preview(role: .manager, visions: [.preview(status: .achieved)]))
}
