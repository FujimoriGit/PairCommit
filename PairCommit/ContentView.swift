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
        case (.player, .none): PlayerVisionView(store: store, reviewing: criteriaReviewing)
        case (.player, .some): PlayerTaskView(store: store)
        }
    }

    // Apple Intelligence が使えない端末では下読みごと出さない
    var criteriaReviewing: (any CriteriaReviewing)? {
        OnDeviceCriteriaReview.isAvailable ? OnDeviceCriteriaReview() : nil
    }

    var rolePicker: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Role.allCases, id: \.self) { role in
                        Button {
                            Task { await start(as: .owner(role)) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(role.label)
                                    .font(.headline)
                                Text(role.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("役割を選んで始める")
                } footer: {
                    Text("役割は後から入れ替えられません。変えるにはペアリングからやり直します。")
                }

                Section {
                    Button("相手の招待を受ける") {
                        Task { await start(as: .participant) }
                    }
                } footer: {
                    Text("始めた側が選ばなかったほうの役割になります。")
                }
                FailureRow(message: failureMessage)
            }
            .navigationTitle("どちらで使いますか")
        }
    }

    func start(as side: PairingSide) async {
        let agreement = await LocalPairing().pair(as: side)
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
