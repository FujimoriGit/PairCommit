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
        .init(knownState: MemoryKnownState(nil), notifying: SilentPartnerActions(), message: { _, _ in "" })
    }

    static func recording(into notifications: RecordingPartnerActions, known: PartnershipState?) -> Self {
        .init(knownState: MemoryKnownState(known), notifying: notifications, message: { _, _ in "操作" })
    }
}

@MainActor
final class RecordingPartnerActions: PartnerActionNotifying {
    private(set) var notices: [PartnerActionNotice] = []

    func deliver(_ notices: [PartnerActionNotice]) async {
        self.notices += notices
    }

    func withdrawAll() async {}
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

private struct SilentPartnerActions: PartnerActionNotifying {
    func deliver(_ notices: [PartnerActionNotice]) async {}

    func withdrawAll() async {}
}
