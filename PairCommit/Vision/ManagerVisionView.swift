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

    @Environment(\.presentingFailure) private var presentingFailure

    var body: some View {
        Screen(role: store.role) {
            content
        }
        .animation(.default, value: store.state)
        .animation(.default, value: failureMessage)
        .sensoryFeedback(.error, trigger: failureMessage) { _, message in message != nil }
        .partnershipSettingsLink()
        .partnershipHistoryLink()
    }
}

// MARK: - Private

private extension ManagerVisionView {
    enum Stage {
        case proposed(Vision)
        case waiting
    }

    var stage: Stage {
        if let proposed = store.state.visions.last(where: { $0.status == .proposed }) {
            return .proposed(proposed)
        }
        return .waiting
    }

    @ViewBuilder
    var content: some View {
        switch stage {
        case .proposed(let vision):
            review(vision)
        case .waiting:
            waiting
        }
    }

    @ViewBuilder
    var waiting: some View {
        if let achieved = store.state.lastAchievedVision {
            AchievementBanner(vision: achieved)
            Placeholder(
                symbol: "tray",
                title: String(localized: "次の起案を待っています"),
                message: String(localized: "\(Role.player.label)がビジョンを起案するとここに出ます")
            )
        } else {
            Placeholder(
                symbol: "tray",
                title: String(localized: "承認待ちのビジョンはありません"),
                message: String(localized: "\(Role.player.label)の起案を待っています")
            )
        }
    }

    @ViewBuilder
    func review(_ vision: Vision) -> some View {
        VisionDetail(vision: vision, note: String(localized: "承認待ち"))
        VStack(spacing: 10) {
            Button("承認する") {
                approve(vision)
            }
            .buttonStyle(.filled)
            Button("起案者に差し戻す") {
                perform { state, role throws(DomainError) in try state.rejectingVision(vision.id, by: role) }
            }
            .buttonStyle(.soft(feedback: .warning))
        }
        FailureNote(message: failureMessage)
    }

    // 承認すると保存の前にこの画面が消えるので、失敗は画面の外へ知らせる
    func approve(_ vision: Vision) {
        perform(failed: presentingFailure) { state, role throws(DomainError) in try state.approvingVision(vision.id, by: role) }
    }

    func perform(
        failed: (@MainActor (String) -> Void)? = nil,
        _ transform: @escaping @Sendable (PartnershipState, Role) throws(DomainError) -> PartnershipState
    ) {
        failureMessage = nil
        Task {
            do throws(PartnershipFailure) {
                try await store.perform(transform)
                failureMessage = nil
            } catch {
                if let failed {
                    failed(error.message)
                } else {
                    failureMessage = error.message
                }
            }
        }
    }
}

#Preview("管理者の起案待ち") {
    NavigationStack {
        ManagerVisionView(store: .preview(role: .manager, visions: []))
            .environment(\.resettingPartnership) { nil }
    }
}

#Preview("管理者の承認待ち") {
    NavigationStack {
        ManagerVisionView(store: .preview(role: .manager, visions: [
            .preview(status: .proposed, deadline: .preview, why: "次の健康診断で再検査を言い渡されたくない")
        ]))
    }
}

#Preview("管理者の達成直後") {
    NavigationStack {
        ManagerVisionView(store: .preview(role: .manager, visions: [.preview(status: .achieved)]))
    }
}
