//
//  PartnershipSettingsView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Application
import Domain
import SwiftUI

extension EnvironmentValues {
    @Entry var resettingPartnership: (@Sendable () async -> String?)?
}

struct PartnershipSettingsView: View {
    let store: PartnershipStore

    @Environment(\.resettingPartnership) private var reset
    @State private var confirming = false
    @State private var failureMessage: String?
    @Environment(\.playingFeedback) private var playingFeedback

    var body: some View {
        Screen(role: store.role) {
            Panel(title: String(localized: .settingsName)) {
                NamingForm(store: store)
            }
            Button(.settingsRepair, role: .destructive) {
                confirming = true
            }
            .buttonStyle(.soft(feedback: .impact(weight: .light)))
        }
        .navigationTitle(.commonSettings)
        .confirmationDialog(.settingsRepairConfirmationTitle, isPresented: $confirming) {
            Button(.settingsRepair, role: .destructive) {
                playingFeedback?(.warning)
                Task { failureMessage = await reset?() }
            }
        } message: {
            Text(.settingsRepairConfirmationMessage)
        }
        .alert(.settingsRepairFailed, isPresented: Binding(presenting: $failureMessage)) {
            Button(.commonOk) {}
        } message: {
            Text(failureMessage ?? "")
        }
    }
}

#Preview("ペアリングの設定") {
    NavigationStack {
        PartnershipSettingsView(store: .preview(role: .manager, visions: []))
    }
}
