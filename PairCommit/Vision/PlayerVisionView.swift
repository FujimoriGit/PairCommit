//
//  PlayerVisionView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Application
import Domain
import Infrastructure
import SwiftUI

struct PlayerVisionView: View {
    let store: PartnershipStore

    @State private var statement = ""
    @State private var doneCriteria = ""
    @State private var failureMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Role.player.label)
        }
    }
}

// MARK: - Private

private extension PlayerVisionView {
    var content: some View {
        Group {
            if let active = store.state.activeVision {
                summary(of: active, note: "進行中")
            } else if let proposed = store.state.visions.last(where: { $0.status == .proposed }) {
                summary(of: proposed, note: "管理者の承認を待っています")
            } else if let draft = store.state.visions.last(where: { $0.status == .draft }) {
                draftDetail(draft)
            } else {
                draftForm
            }
        }
    }

    var draftForm: some View {
        Form {
            Section("ビジョン") {
                TextField("何を達成したいか", text: $statement, axis: .vertical)
            }
            Section("達成基準") {
                TextField("どうなれば達成か", text: $doneCriteria, axis: .vertical)
            }
            Section {
                Button("起案する") {
                    perform { state throws(DomainError) in try state.draftingVision(
                        statement: statement,
                        doneCriteria: doneCriteria,
                        by: store.role
                    ).state }
                }
                .disabled(statement.isEmpty || doneCriteria.isEmpty)
            }
            FailureRow(message: failureMessage)
        }
    }

    func draftDetail(_ vision: Vision) -> some View {
        Form {
            visionFields(vision)
            Section {
                Button("管理者に提出する") {
                    perform { state throws(DomainError) in try state.proposingVision(vision.id, by: store.role) }
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
        Group {
            Section("ビジョン") {
                Text(vision.statement)
            }
            Section("達成基準") {
                Text(vision.doneCriteria)
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

#Preview("プレイヤーの起案前") {
    PlayerVisionView(store: .preview(role: .player, visions: []))
}

#Preview("プレイヤーの提出待ち") {
    PlayerVisionView(store: .preview(role: .player, visions: [.preview(status: .draft)]))
}

#Preview("プレイヤーの承認待ち") {
    PlayerVisionView(store: .preview(role: .player, visions: [.preview(status: .proposed)]))
}
