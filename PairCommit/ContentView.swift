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
    let invitationLinks: AsyncStream<URL>
    let makeCriteriaReviewing: () -> (any CriteriaReviewing)?

    @State private var linkRefusal: PartnershipSession.LinkRefusal?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .animation(.default, value: session.store == nil)
            .animation(.default, value: session.nearby.phase == .idle)
            .animation(.default, value: session.remote.phase == .idle)
            .task {
                for await link in invitationLinks {
                    accept(link)
                }
            }
            .task { await session.resumeRemainingPairing() }
            .alert(linkRefusal?.title ?? "", isPresented: Binding(presenting: $linkRefusal)) {
                Button(.commonOk) {}
            } message: {
                Text(linkRefusal?.message ?? "")
            }
            .scrollIndicators(.hidden)
    }
}

// MARK: - Private

private extension ContentView {
    @ViewBuilder
    var content: some View {
        switch session.stage {
        case .paired(let store):
            paired(store)
        case .connecting(let failure):
            ReconnectingView(
                failureMessage: failure?.message,
                onRetry: { Task { await session.retryConnecting() } },
                onStartOver: { Task { await session.startOver() } }
            )
            .task { await session.connect() }
        case .pairingRemotely:
            remoteScreen
        case .choosingRole(let interruption):
            rolePicker(interruption)
        case .pairingNearby:
            PairingView(phase: session.nearby.phase, onCancel: session.nearby.reset)
                .task(id: session.nearby.phase) { await session.finishNearbyPairing() }
        }
    }

    func paired(_ store: PartnershipStore) -> some View {
        PartnershipTabs(session: session, store: store, makeCriteriaReviewing: makeCriteriaReviewing)
            .tint(store.role.accent)
            .task {
                for await _ in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification) {
                    try? await store.refresh()
                }
            }
            .task(id: store.state) { await session.followStateChange(isActive: scenePhase == .active) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    session.markCurrentStateSeen()
                }
            }
            .sensoryFeedback(.error, trigger: store.saveFailure) { _, failure in failure != nil }
            .alert(
                .rootOperationFailed,
                isPresented: .init(get: { store.saveFailure != nil }, set: { _ in store.dismissSaveFailure() })
            ) {
                Button(.commonOk) {}
            } message: {
                Text(store.saveFailure?.message ?? "")
            }
    }

    func rolePicker(_ interruption: PartnershipSession.Interruption?) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Role.allCases, id: \.self) { role in
                        Button {
                            session.chosenRole = role
                        } label: {
                            ChoiceCard(symbol: role.symbol, title: role.label, summary: role.summary, accent: role.accent)
                        }
                        .buttonStyle(.choice)
                    }

                    Text(.rolePickerNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    FailureNote(message: interruption?.message)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .background(Backdrop())
            .navigationTitle(.rolePickerTitle)
            .navigationDestination(item: Bindable(session).chosenRole) { role in
                PairingMethodView(
                    role: role,
                    onNearby: { session.pairNearby(as: role) },
                    onRemote: { session.invite(ownerRole: role) }
                )
            }
        }
    }

    var remoteScreen: some View {
        Group {
            switch session.remote.phase {
            case .inviting:
                InvitationView(
                    url: session.remote.invitationURL,
                    partnerRole: session.remote.partnerRole,
                    failureMessage: session.remote.failure?.message,
                    isCreatingLink: session.remote.isCreatingLink,
                    isCancelling: session.remote.isCancelling,
                    onRetry: session.remote.retry,
                    onCancel: { Task { await session.cancelRemotePairing() } }
                )
            case .joining, .idle:
                JoiningView(
                    failureMessage: session.remote.failure?.message,
                    isCancelling: session.remote.isCancelling,
                    onRetry: session.remote.retry,
                    onCancel: { Task { await session.cancelRemotePairing() } }
                )
            }
        }
        .task(id: session.remote.failure == nil) { await session.pairRemotely() }
    }

    func accept(_ link: URL) {
        do throws(PartnershipSession.LinkRefusal) {
            try session.accept(link)
        } catch {
            linkRefusal = error
        }
    }
}

#Preview("役割の選択") {
    ContentView(session: .preview, invitationLinks: AsyncStream { $0.finish() }, makeCriteriaReviewing: { nil })
}
