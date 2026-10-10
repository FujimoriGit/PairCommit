//
//  PartnerActionPosting.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import Foundation

extension PartnerActionNotifying {
    /// `previous` から `state` までに、相手がその役割に向けて行った操作を通知する。
    public func post(
        for role: Role,
        in state: PartnershipState,
        since previous: PartnershipState,
        message: @Sendable (PartnerAction) -> String
    ) async {
        let notices = state.partnerActions(since: previous, for: role).map {
            PartnerActionNotice(action: $0, message: message($0))
        }
        guard !notices.isEmpty else { return }
        await deliver(notices)
    }
}
