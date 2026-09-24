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
            content
        }
        .partnershipReset()
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
                title: "次の起案を待っています",
                message: "\(Role.player.label)がビジョンを起案するとここに出ます"
            )
        } else {
            Placeholder(
                symbol: "tray",
                title: "承認待ちのビジョンはありません",
                message: "\(Role.player.label)の起案を待っています"
            )
        }
    }

    @ViewBuilder
    func review(_ vision: Vision) -> some View {
        VisionDetail(vision: vision, note: "承認待ち")
        VStack(spacing: 10) {
            Button("承認する") {
                perform { state throws(DomainError) in try state.approvingVision(vision.id, by: store.role) }
            }
            .buttonStyle(.filled)
            Button("起案者に差し戻す") {
                perform { state throws(DomainError) in try state.rejectingVision(vision.id, by: store.role) }
            }
            .buttonStyle(.soft)
        }
        FailureNote(message: failureMessage)
    }

    func perform(_ transform: @escaping @Sendable (PartnershipState) throws(DomainError) -> PartnershipState) {
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
    NavigationStack {
        ManagerVisionView(store: .preview(role: .manager, visions: []))
            .environment(\.resettingPartnership) { nil }
    }
}

#Preview("管理者の承認待ち") {
    NavigationStack {
        ManagerVisionView(store: .preview(role: .manager, visions: [
            .preview(status: .proposed, deadline: .preview, why: "次の健康診断で再検査を言い渡されたくない"),
        ]))
    }
}

#Preview("管理者の達成直後") {
    NavigationStack {
        ManagerVisionView(store: .preview(role: .manager, visions: [.preview(status: .achieved)]))
    }
}
