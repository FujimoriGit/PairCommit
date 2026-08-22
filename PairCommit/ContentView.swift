//
//  ContentView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Application
import Domain
import Infrastructure
import SwiftUI

struct ContentView: View {
    @State private var store: PartnershipStore?
    @State private var failure: String?

    var body: some View {
        if let store {
            screen(for: store)
        } else {
            rolePicker
        }
    }
}

// MARK: - Private

private extension ContentView {
    @ViewBuilder
    func screen(for store: PartnershipStore) -> some View {
        switch (store.role, store.state.activeVision) {
        case (.manager, .none): ManagerVisionView(store: store)
        case (.manager, .some): ManagerTaskView(store: store)
        case (.player, .none): PlayerVisionView(store: store)
        case (.player, .some): PlayerTaskView(store: store)
        }
    }

    var rolePicker: some View {
        VStack(spacing: 24) {
            Text("どちらで使いますか")
                .font(.title2.bold())

            ForEach(Role.allCases, id: \.self) { role in
                Button(role.label) {
                    Task { await start(as: role) }
                }
                .buttonStyle(.borderedProminent)
            }

            if let failure {
                Text(failure)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    func start(as role: Role) async {
        do {
            let agreement = await LocalPairing().pair(as: role)
            let paired = try PartnershipState().establishingPairing(ownerRole: agreement.ownerRole)
            let started = PartnershipStore(
                role: agreement.role,
                synchronizer: InMemorySynchronizer(initialState: paired)
            )
            try await started.start()
            store = started
        } catch {
            failure = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
