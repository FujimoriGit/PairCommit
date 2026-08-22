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
    @State private var failureMessage: String?

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

            if let failureMessage {
                Text(failureMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    func start(as role: Role) async {
        let agreement = await LocalPairing().pair(as: role)
        let paired: PartnershipState
        do {
            paired = try PartnershipState().establishingPairing(ownerRole: agreement.ownerRole)
        } catch {
            failureMessage = error.message
            return
        }

        let started = PartnershipStore(
            role: agreement.role,
            synchronizer: InMemorySynchronizer(initialState: paired)
        )
        do {
            try await started.start()
        } catch {
            failureMessage = error.message
            return
        }
        store = started
    }
}

#Preview {
    ContentView()
}
