//
//  PartnershipSettingsView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Application
import Domain
import SwiftUI

struct PartnershipSettingsView: View {
    let session: PartnershipSession
    let store: PartnershipStore

    @State private var confirming = false
    @State private var failureMessage: String?

    var body: some View {
        Screen(role: store.role) {
            Panel(title: String(localized: .settingsName)) {
                NamingForm(store: store)
            }
            Button(.settingsRepair, role: .destructive) {
                confirming = true
            }
            .buttonStyle(.soft(feedback: .lightImpact))
        }
        .navigationTitle(.commonSettings)
        .confirmationDialog(.settingsRepairConfirmationTitle, isPresented: $confirming) {
            Button(.settingsRepair, role: .destructive) {
                Haptic.warning.play()
                endPartnership()
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

// MARK: - Private

private extension PartnershipSettingsView {
    func endPartnership() {
        Task {
            do throws(PairingFailure) {
                try await session.endPartnership()
            } catch {
                failureMessage = error.message
            }
        }
    }
}

#Preview("ペアリングの設定") {
    NavigationStack {
        PartnershipSettingsView(session: .preview, store: .preview(role: .manager, visions: []))
    }
}
