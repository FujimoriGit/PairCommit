//
//  PartnershipSettingsView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import SwiftUI

struct PartnershipSettingsView: View {
    let role: Role

    @Environment(\.resettingPartnership) private var reset
    @State private var confirming = false
    @State private var failureMessage: String?

    var body: some View {
        Screen(role: role) {
            Button(.settingsRepair, role: .destructive) {
                confirming = true
            }
            .buttonStyle(.soft)
        }
        .navigationTitle(.commonSettings)
        .confirmationDialog(.settingsRepairConfirmationTitle, isPresented: $confirming) {
            Button(.settingsRepair, role: .destructive) {
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
        PartnershipSettingsView(role: .manager)
    }
}
