//
//  PartnershipHistory.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/05
//

import Domain
import SwiftUI

extension View {
    func partnershipHistoryLink() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: PartnershipHistoryRoute()) {
                    Label("記録", systemImage: "clock.arrow.circlepath")
                }
            }
        }
    }

    // 遷移先をリンクの側に置くと、リンクを持つ画面が入れ替わったときに開いている記録も閉じる
    func partnershipHistoryDestination(_ state: PartnershipState) -> some View {
        navigationDestination(for: PartnershipHistoryRoute.self) { _ in
            PartnershipHistoryView(state: state)
        }
    }
}

// MARK: - Private

private struct PartnershipHistoryRoute: Hashable {}
