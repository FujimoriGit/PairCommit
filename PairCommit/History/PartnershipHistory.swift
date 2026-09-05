//
//  PartnershipHistory.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/05
//

import Domain
import SwiftUI

extension View {
    func partnershipHistory(_ state: PartnershipState) -> some View {
        modifier(PartnershipHistory(state: state))
    }
}

// MARK: - Private

private struct PartnershipHistory: ViewModifier {
    let state: PartnershipState

    @State private var showing = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("記録", systemImage: "clock.arrow.circlepath") {
                        showing = true
                    }
                }
            }
            .navigationDestination(isPresented: $showing) {
                PartnershipHistoryView(state: state)
            }
    }
}
