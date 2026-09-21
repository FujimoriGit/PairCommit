//
//  ContentView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Application
import Domain
import SwiftUI

struct ContentView: View {
    let session: PartnershipSession

    @State private var savedPairing: MultipeerPairing.Outcome?
    @State private var isResuming: Bool
    @State private var pairing = MultipeerPairing()
    @State private var failureMessage: String?

    init(session: PartnershipSession, savedPairing: MultipeerPairing.Outcome? = nil) {
        self.session = session
        _savedPairing = State(initialValue: savedPairing)
        _isResuming = State(initialValue: savedPairing != nil)
    }

    var body: some View {
        if let store = session.store {
            NavigationStack {
                screen(for: store)
                    .partnershipHistoryDestination(store.state)
            }
            .environment(\.resettingPartnership) { await reset() }
            .task(id: store.state) {
                guard store.state.pairing != nil else {
                    await returnToPicker(with: "パートナーシップは終了しました")
                    return
                }
                await NudgeNotifications.post(for: store.role, in: store.state)
            }
        } else if pairing.phase == .idle, let saved = savedPairing {
            ReconnectingView(
                failureMessage: failureMessage,
                onRetry: { failureMessage = nil },
                onStartOver: { Task { await returnToPicker(with: nil) } }
            )
            .task(id: failureMessage == nil) {
                guard failureMessage == nil else { return }
                await enter(saved, resuming: isResuming)
            }
        } else if pairing.phase == .idle {
            rolePicker
        } else {
            PairingView(phase: pairing.phase, onCancel: pairing.reset)
                .task(id: pairing.phase) {
                    guard pairing.phase == .done else { return }
                    guard let outcome = pairing.outcome else {
                        await returnToPicker(with: "ペアリングの結果を受け取れませんでした")
                        return
                    }
                    SavedPairing.save(outcome)
                    savedPairing = outcome
                    isResuming = false
                    await enter(outcome, resuming: false)
                }
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
                            begin(as: .owner(role))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(role.label)
                                    .font(.headline)
                                Text(role.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .tint(role.accent)
                    }
                } header: {
                    Text("役割を選んで始める")
                } footer: {
                    Text("役割は後から入れ替えられません。始め直しても、最初に選んだ役割のままになります。")
                }

                Section {
                    Button("相手の招待を受ける") {
                        begin(as: .participant)
                    }
                } footer: {
                    Text("始めた側が選ばなかったほうの役割になります。")
                }
                FailureRow(message: failureMessage)
            }
            .navigationTitle("どちらで使いますか")
        }
    }

    func begin(as side: PairingSide) {
        failureMessage = nil
        pairing.start(as: side)
    }

    func enter(_ outcome: MultipeerPairing.Outcome, resuming: Bool) async {
        let synchronizer = CloudKitSynchronizer(
            rootRecordID: outcome.rootRecordID,
            isOwner: outcome.isOwner,
            container: PartnershipShare.container
        )

        let state: PartnershipState
        do {
            state = try await synchronizer.start()
        } catch {
            failureMessage = error.message
            pairing.reset()
            return
        }
        guard let ownerRole = state.pairing?.ownerRole else {
            await returnToPicker(with: resuming ? "パートナーシップは終了しました" : "相手の設定がまだ届いていません")
            return
        }
        let agreement = PairingAgreement(ownerRole: ownerRole, isOwner: outcome.isOwner)
        await NudgeNotifications.requestPermission()
        session.store = PartnershipStore(
            role: agreement.role,
            synchronizer: synchronizer,
            state: state
        )
    }

    func reset() async -> String? {
        guard let outcome = savedPairing else {
            return "端末に残したペアを読めませんでした"
        }
        do {
            try await PartnershipShare.teardown(rootRecordID: outcome.rootRecordID, isOwner: outcome.isOwner)
        } catch {
            return error.localizedDescription
        }
        await returnToPicker(with: nil)
        return nil
    }

    func returnToPicker(with message: String?) async {
        await NudgeNotifications.withdrawAll()
        SavedPairing.clear()
        savedPairing = nil
        failureMessage = message
        session.store = nil
        pairing.reset()
    }
}

#Preview("役割の選択") {
    ContentView(session: PartnershipSession())
}
