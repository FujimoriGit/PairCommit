//
//  StubShare.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Application
import Domain

struct StubShare: PairedShare {
    let isOwner: Bool
    let stored: InMemorySynchronizer

    init(isOwner: Bool, synchronizer: InMemorySynchronizer = .init()) {
        self.isOwner = isOwner
        stored = synchronizer
    }

    func synchronizer() -> any PartnershipSyncing {
        stored
    }

    func save() {}

    func end() async throws(PairingFailure) {}
}
