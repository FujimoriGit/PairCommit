//
//  PartnerActionDoubles.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/31
//

import Application
import Domain
import Foundation

extension PartnerActionAnnouncement {
    static var quiet: Self {
        .init(knownState: MemoryKnownState(nil), unseen: MemoryUnseen(), notifying: SilentPartnerActions(), message: { _, _ in "" })
    }

    static func recording(into notifications: RecordingPartnerActions, known: PartnershipState?) -> Self {
        .init(knownState: MemoryKnownState(known), unseen: MemoryUnseen(), notifying: notifications, message: { _, _ in "操作" })
    }
}

@MainActor
final class RecordingPartnerActions: PartnerActionNotifying {
    private(set) var notices: [PartnerActionNotice] = []
    private(set) var badges: [Int] = []

    func deliver(_ notices: [PartnerActionNotice]) async {
        self.notices += notices
    }

    func withdrawAll() async {}

    func showBadge(_ count: Int) async {
        badges.append(count)
    }
}

final class MemoryKnownState: KnownStateKeeping, @unchecked Sendable {
    private let lock = NSLock()
    private var state: PartnershipState?

    init(_ state: PartnershipState?) {
        self.state = state
    }

    func lastKnown() -> PartnershipState? {
        lock.withLock { state }
    }

    func keep(_ state: PartnershipState) {
        lock.withLock { self.state = state }
    }

    func forget() {
        lock.withLock { state = nil }
    }
}

final class MemoryUnseen: UnseenKeeping, @unchecked Sendable {
    private let lock = NSLock()
    private var unseen = UnseenUpdates()

    func lastUnseen() -> UnseenUpdates {
        lock.withLock { unseen }
    }

    func keep(_ unseen: UnseenUpdates) {
        lock.withLock { self.unseen = unseen }
    }
}

private struct SilentPartnerActions: PartnerActionNotifying {
    func deliver(_ notices: [PartnerActionNotice]) async {}

    func withdrawAll() async {}

    func showBadge(_ count: Int) async {}
}
