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
    let inviting: any PartnershipInviting

    @State private var savedPairing: PairingOutcome?
    @State private var isResuming: Bool
    @State private var pairing: MultipeerPairing
    @State private var invitation: InvitationStep?
    @State private var invitationURL: URL?
    @State private var invitationPolling: Task<Void, Never>?
    @State private var failureMessage: String?
    @State private var refreshFailure: String?
    @State private var linkRefusal: LinkRefusal?
    private let inbox = InvitationLinkInbox.shared

    init(
        session: PartnershipSession,
        sharing: any PartnershipSharing,
        inviting: any PartnershipInviting,
        savedPairing: PairingOutcome?,
        savedInvitation: InvitationStep?
    ) {
        self.session = session
        self.sharing = sharing
        self.inviting = inviting
        _savedPairing = State(initialValue: savedPairing)
        _isResuming = State(initialValue: savedPairing != nil)
        _pairing = State(initialValue: MultipeerPairing(sharing: sharing))
        _invitation = State(initialValue: savedInvitation)
    }

    var body: some View {
        content
            .task(id: inbox.received == nil) {
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
    static let invitationPollingInterval: Duration = .seconds(5)

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
        } else if pairing.phase == .idle, let invitation {
            invitationScreen(invitation)
        } else if pairing.phase == .idle {
            RolePickerView(
                failureMessage: failureMessage,
                onNearby: { begin(with: .role($0)) },
                onRemote: { startInvitation(ownerRole: $0) },
                onAcceptInvitation: { begin(with: .invitation) }
            )
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

    @ViewBuilder
    func invitationScreen(_ step: InvitationStep) -> some View {
        switch step {
        case .sending(let ownerRole), .sent(let ownerRole):
            InvitationView(
                url: invitationURL,
                failureMessage: failureMessage,
                onRetry: { failureMessage = nil },
                onCancel: { Task { await withdrawInvitation() } }
            )
            .task(id: failureMessage == nil) {
                guard failureMessage == nil else { return }
                await poll { await awaitGuest(ownerRole: ownerRole) }
            }
        case .accepting, .joined:
            ReconnectingView(
                failureMessage: failureMessage,
                onRetry: { failureMessage = nil },
                onStartOver: { Task { await leaveInvitation() } }
            )
            .task(id: failureMessage == nil) {
                guard failureMessage == nil else { return }
                await poll { await awaitHost() }
            }
        }
    }

    func begin(with choice: PairingChoice) {
        failureMessage = nil
        pairing.start(with: choice)
    }

    func startInvitation(ownerRole: Role) {
        failureMessage = nil
        invitationURL = nil
        invitation = .sending(ownerRole: ownerRole)
    }

    func receive(_ link: any InvitationLink) {
        if session.store != nil || savedPairing != nil {
            linkRefusal = .alreadyPaired
        } else if invitation != nil || pairing.phase != .idle {
            linkRefusal = .pairingInProgress
        } else {
            failureMessage = nil
            invitation = .accepting(link)
        }
    }

    func awaitGuest(ownerRole: Role) async {
        do {
            if case .sending = invitation {
                invitationURL = try await inviting.send()
                try Task.checkCancellation()
                invitation = .sent(ownerRole: ownerRole)
                SavedInvitation.save(.sent(ownerRole: ownerRole))
            }
            while true {
                let progress = try await inviting.advance(ownerRole: ownerRole)
                try Task.checkCancellation()
                switch progress {
                case .waiting(let url):
                    invitationURL = url
                case .paired(let outcome):
                    finishInvitation(outcome)
                    return
                }
                try await Task.sleep(for: Self.invitationPollingInterval)
            }
        } catch {
            // やめたり画面を離れたりして打ち切られたときは、失敗として出さない。
            guard !Task.isCancelled else { return }
            failureMessage = FailureReason(error).message
        }
    }

    func awaitHost() async {
        do {
            if case .accepting(let link) = invitation {
                let invitationID = try await link.join()
                invitation = .joined(invitationID: invitationID)
                SavedInvitation.save(.joined(invitationID: invitationID))
            }
            guard case .joined(let invitationID) = invitation else { return }
            while true {
                let joined = try await inviting.advanceJoining(invitationID)
                try Task.checkCancellation()
                if let joined {
                    finishInvitation(joined)
                    return
                }
                try await Task.sleep(for: Self.invitationPollingInterval)
            }
        } catch {
            guard !Task.isCancelled else { return }
            failureMessage = FailureReason(error).message
        }
    }

    // つなぎ直しの画面に切り替わり、そこから入る。
    func finishInvitation(_ outcome: PairingOutcome) {
        SavedPairing.save(outcome)
        SavedInvitation.clear()
        invitation = nil
        invitationURL = nil
        savedPairing = outcome
        isResuming = false
    }

    // やめるときは、止まり切るのを待ってから後始末に入る。並んで走ると、後始末のあとで参加や共有の作成が通ってしまう。
    func poll(_ operation: @escaping @MainActor @Sendable () async -> Void) async {
        let polling = Task { await operation() }
        invitationPolling = polling
        await withTaskCancellationHandler { await polling.value } onCancel: { polling.cancel() }
    }

    func stopPolling() async {
        invitationPolling?.cancel()
        await invitationPolling?.value
        invitationPolling = nil
    }

    func withdrawInvitation() async {
        await stopPolling()
        do {
            try await inviting.withdraw()
        } catch {
            failureMessage = FailureReason(error).message
            return
        }
        await returnToPicker(with: nil)
    }

    func leaveInvitation() async {
        await stopPolling()
        if case .joined(let invitationID) = invitation {
            do {
                try await inviting.leave(invitationID)
            } catch {
                failureMessage = FailureReason(error).message
                return
            }
        }
        await returnToPicker(with: nil)
    }

    func enter(_ outcome: PairingOutcome, resuming: Bool) async {
        let synchronizer = sharing.makeSynchronizer(for: outcome)

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
            try await sharing.teardown(outcome)
        } catch {
            return FailureReason(error).message
        }
        await returnToPicker(with: nil)
        return nil
    }

    func returnToPicker(with message: String?) async {
        await NudgeNotifications.withdrawAll()
        SavedPairing.clear()
        SavedInvitation.clear()
        savedPairing = nil
        invitation = nil
        invitationURL = nil
        failureMessage = message
        session.store = nil
        pairing.reset()
    }
}
