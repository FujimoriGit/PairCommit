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
    private let announcement: PartnerActionAnnouncement
    private let nudgeMessage: @Sendable (Nudge, PartnershipState) -> String
    private let failures: any FailureRecording

    public init(
        nudges: any NudgeNotifying,
        announcement: PartnerActionAnnouncement,
        nudgeMessage: @escaping @Sendable (Nudge, PartnershipState) -> String,
        failures: any FailureRecording
    ) {
        self.nudges = nudges
        self.announcement = announcement
        self.nudgeMessage = nudgeMessage
        self.failures = failures
    }

    /// 状態を取り直し、相手がこの端末の役割に向けて行った操作を通知する。前面にいなければ、催促も通知する。
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
        } else if let saved, let started = try await PartnershipStore(starting: saved, failures: failures, announcement: announcement) {
            store = started
        } else {
            return false
        }
        guard !isActive else { return true }
        let state = store.state
        await nudges.post(for: store.role, in: state) { nudgeMessage($0, state) }
        return true
    }
}
