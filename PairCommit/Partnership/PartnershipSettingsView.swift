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
            Button("ペアリングをやり直す", role: .destructive) {
                confirming = true
            }
            .buttonStyle(.soft)
        }
        .navigationTitle("設定")
        .confirmationDialog("ペアリングをやり直しますか", isPresented: $confirming) {
            Button("ペアリングをやり直す", role: .destructive) {
                Task { failureMessage = await reset?() }
            }
        } message: {
            Text("ビジョンとタスクはすべて消えます。相手も最初の画面に戻ります。")
        }
        .alert("ペアリングをやり直せませんでした", isPresented: Binding(presenting: $failureMessage)) {
            Button("OK") {}
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
