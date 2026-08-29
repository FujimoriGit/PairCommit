//
//  PartnershipReset.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/29
//

import SwiftUI

extension EnvironmentValues {
    @Entry var resettingPartnership: @Sendable () async -> Void = {}
}

extension View {
    func partnershipReset() -> some View {
        modifier(PartnershipReset())
    }
}

// MARK: - Private

private struct PartnershipReset: ViewModifier {
    @Environment(\.resettingPartnership) private var reset
    @State private var confirming = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("リセット", systemImage: "arrow.counterclockwise") {
                        confirming = true
                    }
                }
            }
            .confirmationDialog("ペアリングをやり直しますか", isPresented: $confirming) {
                Button("リセットする", role: .destructive) {
                    Task { await reset() }
                }
            } message: {
                Text("ビジョンとタスクはすべて消えます。相手も最初の画面に戻ります。")
            }
    }
}
