//
//  ContentView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Application
import Domain
import SwiftUI
import UIKit

struct ContentView: View {
    let session: PartnershipSession

    @State private var savedPairing: MultipeerPairing.Outcome?
    @State private var isResuming: Bool
    @State private var pairing = MultipeerPairing()
    @State private var failureMessage: String?
    @State private var refreshFailure: String?

    init(session: PartnershipSession, savedPairing: MultipeerPairing.Outcome? = nil) {
        self.session = session
        _savedPairing = State(initialValue: savedPairing)
        _isResuming = State(initialValue: savedPairing != nil)
    }

    var body: some View {
        if let store = session.store {
            NavigationStack {
                screen(for: store)
                    .refreshable { await refresh(store) }
                    .partnershipHistoryDestination(store.state, role: store.role)
            }
            .tint(store.role.accent)
            .task(id: ObjectIdentifier(store)) {
                for await _ in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification) {
                    try? await store.refresh()
                }
            }
            .alert("最新の状態を取得できませんでした", isPresented: Binding(presenting: $refreshFailure)) {
                Button("OK") {}
            } message: {
                Text(refreshFailure ?? "")
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
        case (.manager, .some(let vision)): ManagerTaskView(store: store, vision: vision)
        case (.player, .none): PlayerVisionView(store: store, reviewing: criteriaReviewing)
        case (.player, .some(let vision)): PlayerTaskView(store: store, vision: vision)
        }
    }

    // Apple Intelligence が使えない端末では下読みごと出さない
    var criteriaReviewing: (any CriteriaReviewing)? {
        OnDeviceCriteriaReview.isAvailable ? OnDeviceCriteriaReview() : nil
    }

    var rolePicker: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Role.allCases, id: \.self) { role in
                        Button {
                            begin(as: .owner(role))
                        } label: {
                            roleCard(role)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("役割は後から入れ替えられません。始め直しても、最初に選んだ役割のままになります。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Panel {
                        Button("相手の招待を受ける") {
                            begin(as: .participant)
                        }
                        .buttonStyle(.filled)
                        Text("始めた側が選ばなかったほうの役割になります。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    FailureNote(message: failureMessage)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .background(Backdrop())
            .navigationTitle("どちらで使いますか")
        }
    }

    func roleCard(_ role: Role) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: role.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(role.accent.gradient, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(role.label)
                    .font(.system(.headline, design: .rounded))
                Text(role.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .card(outlined: role.accent.opacity(0.35))
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

    func refresh(_ store: PartnershipStore) async {
        do throws(SyncFailure) {
            try await store.refresh()
        } catch {
            refreshFailure = error.message
        }
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
