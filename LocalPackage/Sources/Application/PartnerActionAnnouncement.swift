//
//  PartnerActionAnnouncement.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/31
//

import Domain
import Foundation

/// 受け取った状態を前に受け取った状態と比べ、相手がその役割に向けて行った操作を通知する。
public struct PartnerActionAnnouncement: Sendable {
    private let knownState: any KnownStateKeeping
    private let notifying: any PartnerActionNotifying
    private let message: @Sendable (PartnerAction, PartnershipState) -> String

    public init(
        knownState: any KnownStateKeeping,
        notifying: any PartnerActionNotifying,
        message: @escaping @Sendable (PartnerAction, PartnershipState) -> String
    ) {
        self.knownState = knownState
        self.notifying = notifying
        self.message = message
    }

    /// サーバーから受け取った状態だけを渡す。
    @MainActor
    func announce(_ received: PartnershipState, to role: Role) async {
        let known = knownState.lastKnown()
        knownState.keep(received)
        guard let known else { return }
        await notifying.post(for: role, in: received, since: known) { message($0, received) }
    }

    func clear() async {
        await notifying.withdrawAll()
        knownState.forget()
    }
}
