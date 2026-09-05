//
//  PartnershipReset.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/29
//

import SwiftUI

extension EnvironmentValues {
    @Entry var resettingPartnership: (@Sendable () async -> String?)?
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
    @State private var failureMessage: String?

    func body(content: Content) -> some View {
        content
            .toolbar {
                if let reset {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("リセット", systemImage: "arrow.counterclockwise") {
                            confirming = true
                        }
                    }
                }
            }
            .confirmationDialog("ペアリングをやり直しますか", isPresented: $confirming) {
                Button("リセットする", role: .destructive) {
                    Task { failureMessage = await reset?() }
                }
            } message: {
                Text("ビジョンとタスクはすべて消えます。相手も最初の画面に戻ります。")
            }
            .alert("リセットできませんでした", isPresented: showingFailure) {
                Button("OK") { failureMessage = nil }
            } message: {
                Text(failureMessage ?? "")
            }
    }
}

private extension PartnershipReset {
    var showingFailure: Binding<Bool> {
        Binding(get: { failureMessage != nil }, set: { presented in
            if !presented {
                failureMessage = nil
            }
        })
    }
}
