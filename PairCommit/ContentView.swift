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
    let sharing: any PartnershipSharing

    let inbox: InvitationInbox

    @State private var savedPairing: (any PairedShare)?
    @State private var isResuming: Bool
    @State private var pairing: NearbyPairing
    @State private var remote: RemotePairing
    @State private var methodRole: Role?
    @State private var failureMessage: String?
    @State private var refreshFailure: String?
    @State private var linkRefusal: LinkRefusal?

    init(
        session: PartnershipSession,
        sharing: any PartnershipSharing,
        inviting: any PartnershipInviting,
        inbox: InvitationInbox,
        makeNearbyChannel: @escaping @MainActor () -> any NearbyChannel
    ) {
        self.session = session
        self.sharing = sharing
        self.inbox = inbox
        let savedPairing = sharing.savedShare()
        _savedPairing = State(initialValue: savedPairing)
        _isResuming = State(initialValue: savedPairing != nil)
        _pairing = State(initialValue: NearbyPairing(sharing: sharing, makeChannel: makeNearbyChannel))
        _remote = State(initialValue: RemotePairing(inviting: inviting))
    }

    var body: some View {
        content
            .task(id: inbox.received) {
                guard let link = inbox.received else { return }
                inbox.received = nil
                receive(link)
            }
            .alert(linkRefusal?.title ?? "", isPresented: Binding(presenting: $linkRefusal)) {
                Button("OK") {}
            } message: {
                Text(linkRefusal?.message ?? "")
            }
    }
}

// MARK: - Private

private extension ContentView {
    @ViewBuilder
    var content: some View {
        if let store = session.store {
            NavigationStack {
                screen(for: store)
                    .refreshable { await refresh(store) }
                    .partnershipHistoryDestination(store.state, role: store.role)
                    .partnershipSettingsDestination(role: store.role)
            }
            .tint(store.role.accent)
            .task {
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
                    await returnToPicker(with: String(localized: "パートナーシップは終了しました"))
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
        } else if pairing.phase == .idle, remote.phase != .idle {
            remoteScreen
        } else if pairing.phase == .idle {
            rolePicker
        } else {
            PairingView(phase: pairing.phase, onCancel: pairing.reset)
                .task(id: pairing.phase) {
                    guard pairing.phase == .done else { return }
                    guard let outcome = pairing.outcome else {
                        await returnToPicker(with: String(localized: "ペアリングの結果を受け取れませんでした"))
                        return
                    }
                    outcome.save()
                    savedPairing = outcome
                    isResuming = false
                    await enter(outcome, resuming: false)
                }
        }
    }

    @ViewBuilder
    func screen(for store: PartnershipStore) -> some View {
        switch (store.role, store.state.activeVision) {
        case (.manager, .none): ManagerVisionView(store: store)
        case (.manager, .some(let vision)):
            TimelineView(.everyMinute) { context in
                ManagerTaskView(store: store, vision: vision, now: context.date)
            }
        case (.player, .none): PlayerVisionView(store: store, reviewing: criteriaReviewing)
        case (.player, .some(let vision)):
            TimelineView(.everyMinute) { context in
                PlayerTaskView(store: store, vision: vision, now: context.date)
            }
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
                            methodRole = role
                        } label: {
                            roleCard(role)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("役割は途中で入れ替えられません。入れ替えるには、ペアリングをやり直します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Panel {
                        Button("相手の招待を受ける") {
                            begin(with: .invitation)
                        }
                        .buttonStyle(.filled)
                        Text("相手が選ばなかったほうの役割になります。")
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
            .navigationDestination(item: $methodRole) { role in
                PairingMethodView(
                    role: role,
                    onNearby: { begin(with: .role(role)) },
                    onRemote: { invite(ownerRole: role) }
                )
            }
        }
    }

    func roleCard(_ role: Role) -> some View {
        ChoiceCard(symbol: role.symbol, title: role.label, summary: role.summary, accent: role.accent)
    }

    var remoteScreen: some View {
        Group {
            switch remote.phase {
            case .inviting:
                InvitationView(
                    url: remote.invitationURL,
                    failureMessage: remote.failure?.message,
                    onRetry: remote.retry,
                    onCancel: { Task { await cancelRemote() } }
                )
            case .joining, .idle:
                ReconnectingView(
                    failureMessage: remote.failure?.message,
                    onRetry: remote.retry,
                    onStartOver: { Task { await cancelRemote() } }
                )
            }
        }
        .task(id: remote.failure == nil) {
            guard remote.failure == nil else { return }
            guard let outcome = await remote.run() else {
                if remote.phase == .idle {
                    await returnToPicker(with: nil)
                }
                return
            }
            outcome.save()
            savedPairing = outcome
            isResuming = false
            remote.reset()
        }
    }

    func begin(with choice: PairingChoice) {
        failureMessage = nil
        methodRole = nil
        pairing.start(with: choice)
    }

    func invite(ownerRole: Role) {
        failureMessage = nil
        methodRole = nil
        remote.invite(ownerRole: ownerRole)
    }

    func receive(_ link: URL) {
        if session.store != nil || savedPairing != nil {
            linkRefusal = .alreadyPaired
        } else if remote.phase != .idle || pairing.phase != .idle {
            linkRefusal = .pairingInProgress
        } else {
            failureMessage = nil
            methodRole = nil
            remote.receive(link)
        }
    }

    func cancelRemote() async {
        await remote.cancel()
        guard remote.phase == .idle else { return }
        await returnToPicker(with: nil)
    }

    func enter(_ outcome: any PairedShare, resuming: Bool) async {
        let started: PartnershipStore?
        do throws(SyncFailure) {
            started = try await PartnershipStore(starting: outcome)
        } catch {
            failureMessage = error.message
            pairing.reset()
            return
        }
        guard let started else {
            await returnToPicker(with: resuming ? String(localized: "パートナーシップは終了しました") : String(localized: "相手の設定がまだ届いていません"))
            return
        }
        await NudgeNotifications.requestPermission()
        session.store = started
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
            return String(localized: "端末に残したペアを読めませんでした")
        }
        do throws(PairingFailure) {
            try await outcome.end()
        } catch {
            return error.message
        }
        await returnToPicker(with: nil)
        return nil
    }

    func returnToPicker(with message: String?) async {
        await NudgeNotifications.withdrawAll()
        sharing.clearSavedShare()
        savedPairing = nil
        remote.reset()
        failureMessage = message
        session.store = nil
        pairing.reset()
    }
}

#Preview("役割の選択") {
    ContentView(
        session: PartnershipSession(),
        sharing: PreviewSharing(),
        inviting: PreviewInviting(),
        inbox: InvitationInbox(),
        makeNearbyChannel: { PreviewNearbyChannel() }
    )
}
