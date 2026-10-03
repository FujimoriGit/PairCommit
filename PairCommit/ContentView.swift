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

extension EnvironmentValues {
    @Entry var achievingVision: (@MainActor () -> Void)?
    @Entry var presentingFailure: (@MainActor (String) -> Void)?
}

struct ContentView: View {
    let session: PartnershipSession
    let sharing: any PartnershipSharing
    let notifications: any NudgeNotifying
    let makeCriteriaReviewing: () -> (any CriteriaReviewing)?

    let invitationLinks: AsyncStream<URL>

    @State private var savedPairing: (any PairedShare)?
    @State private var isResuming: Bool
    @State private var pairing: NearbyPairing
    @State private var remote: RemotePairing
    @State private var methodRole: Role?
    @State private var failureMessage: String?
    @State private var refreshFailure: String?
    @State private var linkRefusal: LinkRefusal?
    @State private var achievements = 0
    @State private var operationFailure: String?

    init(
        session: PartnershipSession,
        sharing: any PartnershipSharing,
        inviting: any PartnershipInviting,
        invitationLinks: AsyncStream<URL>,
        notifications: any NudgeNotifying,
        makeCriteriaReviewing: @escaping () -> (any CriteriaReviewing)?,
        makeNearbyChannel: @escaping @MainActor () -> any NearbyChannel
    ) {
        self.session = session
        self.sharing = sharing
        self.invitationLinks = invitationLinks
        self.notifications = notifications
        self.makeCriteriaReviewing = makeCriteriaReviewing
        let savedPairing = sharing.savedShare()
        _savedPairing = State(initialValue: savedPairing)
        _isResuming = State(initialValue: savedPairing != nil)
        _pairing = State(initialValue: NearbyPairing(sharing: sharing, makeChannel: makeNearbyChannel))
        _remote = State(initialValue: RemotePairing(inviting: inviting))
    }

    var body: some View {
        content
            .animation(.default, value: session.store == nil)
            .animation(.default, value: pairing.phase == .idle)
            .animation(.default, value: remote.phase == .idle)
            .task {
                for await link in invitationLinks {
                    receive(link)
                }
            }
            .alert(linkRefusal?.title ?? "", isPresented: Binding(presenting: $linkRefusal)) {
                Button(.commonOk) {}
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
            .alert(.rootRefreshFailed, isPresented: Binding(presenting: $refreshFailure)) {
                Button(.commonOk) {}
            } message: {
                Text(refreshFailure ?? "")
            }
            .environment(\.resettingPartnership) { await reset() }
            .task(id: store.state) {
                guard store.state.pairing != nil else {
                    await returnToPicker(with: String(localized: .rootPartnershipEnded))
                    return
                }
                let state = store.state
                await notifications.post(for: store.role, in: state) { $0.message(in: state) }
            }
            .environment(\.achievingVision) { achievements += 1 }
            .sensoryFeedback(.success, trigger: achievements)
            .environment(\.presentingFailure) { operationFailure = $0 }
            .sensoryFeedback(.error, trigger: operationFailure) { _, message in message != nil }
            .alert(.rootOperationFailed, isPresented: Binding(presenting: $operationFailure)) {
                Button(.commonOk) {}
            } message: {
                Text(operationFailure ?? "")
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
                        await returnToPicker(with: String(localized: .rootPairingResultMissing))
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
        case (.player, .none): PlayerVisionView(store: store, reviewing: makeCriteriaReviewing())
        case (.player, .some(let vision)):
            TimelineView(.everyMinute) { context in
                PlayerTaskView(store: store, vision: vision, now: context.date)
            }
        }
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

                    Text(.rolePickerNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Panel {
                        Button(.rolePickerAcceptInvitation) {
                            begin(with: .invitation)
                        }
                        .buttonStyle(.filled)
                        Text(.rolePickerAcceptInvitationNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    FailureNote(message: failureMessage)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .background(Backdrop())
            .navigationTitle(.rolePickerTitle)
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
            await returnToPicker(with: resuming ? String(localized: .rootPartnershipEnded) : String(localized: .rootPartnerSetupMissing))
            return
        }
        await notifications.requestPermission()
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
            return String(localized: .rootSavedPairUnreadable)
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
        await notifications.withdrawAll()
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
        invitationLinks: AsyncStream { $0.finish() },
        notifications: PreviewNudgeNotifications(),
        makeCriteriaReviewing: { nil },
        makeNearbyChannel: { PreviewNearbyChannel() }
    )
}
