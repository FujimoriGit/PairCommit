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
    private let nudges: any NudgeNotifying
    private let nudgeMessage: @Sendable (Nudge, PartnershipState) -> String

    public init(
        nudges: any NudgeNotifying,
        nudgeMessage: @escaping @Sendable (Nudge, PartnershipState) -> String
    ) {
        self.nudges = nudges
        self.nudgeMessage = nudgeMessage
    }

    /// 状態を取り直し、相手がこの端末の役割に向けて行った操作を通知する。前面にいなければ、催促も通知する。
    /// まだペアにつないでいなければ、つないでから取り直す。ペアを組んでいなければ何もせず false を返す。
    @MainActor
    public func receive(in session: PartnershipSession, isActive: Bool) async throws(SyncFailure) -> Bool {
        guard let store = try await session.connectedStore() else { return false }
        try await store.refresh()
        guard !isActive else { return true }
        let state = store.state
        await nudges.post(for: store.role, in: state) { nudgeMessage($0, state) }
        return true
    }
}
