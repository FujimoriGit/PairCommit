//
//  PartnerChangeReception.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import Foundation

/// 相手の変更を知らせるプッシュを受けたときに、状態を取り直して通知する。
public struct PartnerChangeReception: Sendable {
    private let knownState: any KnownStateKeeping
    private let nudges: any NudgeNotifying
    private let partnerActions: any PartnerActionNotifying
    private let nudgeMessage: @Sendable (Nudge, PartnershipState) -> String
    private let partnerActionMessage: @Sendable (PartnerAction, PartnershipState) -> String

    public init(
        knownState: any KnownStateKeeping,
        nudges: any NudgeNotifying,
        partnerActions: any PartnerActionNotifying,
        nudgeMessage: @escaping @Sendable (Nudge, PartnershipState) -> String,
        partnerActionMessage: @escaping @Sendable (PartnerAction, PartnershipState) -> String
    ) {
        self.knownState = knownState
        self.nudges = nudges
        self.partnerActions = partnerActions
        self.nudgeMessage = nudgeMessage
        self.partnerActionMessage = partnerActionMessage
    }

    /// 状態を取り直し、前面にいなければ、催促と、相手がこの端末の役割に向けて行った操作を通知する。
    /// 画面がまだ状態を持っていなければ `saved` のペアから始める。始めるペアがなければ何もせず false を返す。
    @MainActor
    public func receive(
        into current: PartnershipStore?,
        orStartingFrom saved: (any PairedShare)?,
        isActive: Bool
    ) async throws(SyncFailure) -> Bool {
        let store: PartnershipStore
        if let current {
            try await current.refresh()
            store = current
        } else if let saved, let started = try await PartnershipStore(starting: saved) {
            store = started
        } else {
            return false
        }
        let state = store.state
        // 読んでから残すまでに中断を挟まない。挟むと、続けて届いたプッシュが同じ状態と比べ、同じ操作を2度知らせる。
        let known = knownState.lastKnown()
        knownState.keep(state)
        // 前面では画面の側も催促を掲示するので、二重に出すと鳴り直す。相手の操作は画面で見える。
        guard !isActive else { return true }
        await nudges.post(for: store.role, in: state) { nudgeMessage($0, state) }
        if let known {
            await partnerActions.post(for: store.role, in: state, since: known) { partnerActionMessage($0, state) }
        }
        return true
    }
}
