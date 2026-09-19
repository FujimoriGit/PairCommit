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

    @State private var pairing = MultipeerPairing()
    @State private var failureMessage: String?

    var body: some View {
        if let store = session.store {
            NavigationStack {
                screen(for: store)
                    .partnershipHistoryDestination(store.state)
            }
            .environment(\.resettingPartnership) { await reset() }
            .task(id: store.state) {
                guard store.state.pairing != nil else {
                    await NudgeNotifications.withdrawAll()
                    returnToPicker(with: "パートナーシップは終了しました")
                    return
                }
                await NudgeNotifications.post(store.state.nudges(for: store.role), in: store.state)
            }
        } else if pairing.phase == .idle, let saved = SavedPairing.load() {
            reconnecting
                .task(id: failureMessage == nil) {
                    guard failureMessage == nil else { return }
                    await enter(saved)
                }
        } else if pairing.phase == .idle {
            rolePicker
        } else {
            PairingView(phase: pairing.phase, onCancel: pairing.reset)
                .task(id: pairing.phase) {
                    guard pairing.phase == .done else { return }
                    guard let outcome = pairing.outcome else {
                        returnToPicker(with: "ペアリングの結果を受け取れませんでした")
                        return
                    }
                    await enter(outcome)
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
                                    .foregroundStyle(.secondary)
                            }
                        }
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

    @ViewBuilder
    var reconnecting: some View {
        if let failureMessage {
            ContentUnavailableView {
                Label("相手とつながりませんでした", systemImage: "wifi.exclamationmark")
            } description: {
                Text(failureMessage)
            } actions: {
                Button("もう一度試す") {
                    self.failureMessage = nil
                }
                .buttonStyle(.borderedProminent)
                Button("役割の選択からやり直す", role: .destructive) {
                    returnToPicker(with: nil)
                }
            }
        } else {
            ProgressView("前回の相手とつないでいます…")
        }
    }

    func enter(_ outcome: MultipeerPairing.Outcome) async {
        let synchronizer = CloudKitSynchronizer(
            rootRecordID: outcome.rootRecordID,
            isOwner: outcome.isOwner,
            container: PartnershipShare.container
        )

        let state: PartnershipState
        do {
            state = try await synchronizer.start()
        } catch {
            // 残したペアは消さない。つながらないだけで、ペアが終わったとは限らない。
            failureMessage = error.message
            pairing.reset()
            return
        }
        guard let ownerRole = state.pairing?.ownerRole else {
            returnToPicker(with: "相手の設定がまだ届いていません")
            return
        }
        do {
            try SavedPairing.save(outcome)
        } catch {
            returnToPicker(with: error.localizedDescription)
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
        guard let outcome = SavedPairing.load() else {
            return "ペアリングの結果を受け取れませんでした"
        }
        do {
            try await PartnershipShare.teardown(rootRecordID: outcome.rootRecordID, isOwner: outcome.isOwner)
        } catch {
            return error.localizedDescription
        }
        await NudgeNotifications.withdrawAll()
        returnToPicker(with: nil)
        return nil
    }

    func returnToPicker(with message: String?) {
        SavedPairing.clear()
        failureMessage = message
        session.store = nil
        pairing.reset()
    }
}

#Preview("役割の選択") {
    ContentView(session: PartnershipSession())
}
