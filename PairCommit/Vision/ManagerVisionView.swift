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
        Screen(role: store.role) {
            PartnerLine(pairing: store.state.pairing, role: store.role)
            content
        }
        .animation(.default, value: store.state)
        .animation(.default, value: failureMessage)
        .sensoryFeedback(.error, trigger: failureMessage) { _, message in message != nil }
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
                title: String(localized: .managerVisionNextTitle),
                message: String(localized: .managerVisionNextMessage(Role.player.label))
            )
        } else {
            Placeholder(
                symbol: "tray",
                title: String(localized: .managerVisionEmptyTitle),
                message: String(localized: .managerVisionEmptyMessage(Role.player.label))
            )
        }
    }

    @ViewBuilder
    func review(_ vision: Vision) -> some View {
        VisionDetail(vision: vision, note: String(localized: .commonAwaitingApproval))
        VStack(spacing: 10) {
            Button(.commonApprove) {
                approve(vision)
            }
            .buttonStyle(.filled)
            Button(.managerVisionSendBack) {
                perform { state, role throws(VisionRejectionError) in try state.rejectingVision(vision.id, by: role) }
            }
            .buttonStyle(.soft(feedback: .warning))
        }
        FailureNote(message: failureMessage)
    }

    // 承認すると保存の前にこの画面が消える
    func approve(_ vision: Vision) {
        failureMessage = nil
        Task {
            await store.send { state, role throws(VisionApprovalError) in try state.approvingVision(vision.id, by: role) }
        }
    }

    func perform<Rejection: PresentableError>(
        _ transform: @escaping @Sendable (PartnershipState, Role) throws(Rejection) -> PartnershipState
    ) {
        failureMessage = nil
        Task {
            do throws(PartnershipFailure<Rejection>) {
                try await store.perform(transform)
                failureMessage = nil
            } catch {
                failureMessage = error.message
            }
        }
    }
}

#Preview("管理者の起案待ち") {
    NavigationStack {
        ManagerVisionView(store: .preview(role: .manager, visions: []))
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
