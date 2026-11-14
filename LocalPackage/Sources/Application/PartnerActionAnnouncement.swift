//
//  PartnerActionAnnouncement.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/31
//

import Domain
import Foundation

/// 受け取った状態を前に受け取った状態と比べ、相手がその役割に向けて行った操作を通知し、まだ見ていない更新として数える。
public struct PartnerActionAnnouncement: Sendable {
    private let knownState: any KnownStateKeeping
    private let unseen: any UnseenKeeping
    private let notifying: any PartnerActionNotifying
    private let message: @Sendable (PartnerAction, PartnershipState) -> String

    public init(
        knownState: any KnownStateKeeping,
        unseen: any UnseenKeeping,
        notifying: any PartnerActionNotifying,
        message: @escaping @Sendable (PartnerAction, PartnershipState) -> String
    ) {
        self.knownState = knownState
        self.unseen = unseen
        self.notifying = notifying
        self.message = message
    }

    var lastUnseen: UnseenUpdates {
        unseen.lastUnseen()
    }

    /// サーバーから受け取った状態だけを渡す。
    @MainActor
    func announce(_ received: PartnershipState, to role: Role) async {
        let known = knownState.lastKnown()
        knownState.keep(received)
        let actions = known.map { received.partnerActions(since: $0, for: role) } ?? []
        if !actions.isEmpty {
            await notifying.deliver(actions.map { PartnerActionNotice(action: $0, message: message($0, received)) })
        }
        await record(unseen.lastUnseen().adding(actions).keeping(in: received))
    }

    @MainActor
    func see(_ subjects: Set<Note.Subject>, in state: PartnershipState) async {
        await record(unseen.lastUnseen().seeing(subjects).keeping(in: state))
    }

    func clear() async {
        await notifying.withdrawAll()
        knownState.forget()
        unseen.keep(.init())
        await notifying.showBadge(0)
    }
}

// MARK: - Private

private extension PartnerActionAnnouncement {
    func record(_ next: UnseenUpdates) async {
        unseen.keep(next)
        await notifying.showBadge(next.total)
    }
}
