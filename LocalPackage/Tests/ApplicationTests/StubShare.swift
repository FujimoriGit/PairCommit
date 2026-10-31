//
//  StubShare.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Domain

struct StubShare: PairedShare {
    let isOwner: Bool
    let stored: InMemorySynchronizer
    let partnerJoined: Bool

    init(isOwner: Bool, synchronizer: InMemorySynchronizer = .init(), partnerJoined: Bool = true) {
        self.isOwner = isOwner
        stored = synchronizer
        self.partnerJoined = partnerJoined
    }

    func synchronizer() -> any PartnershipSyncing {
        stored
    }

    func save() {}

    func hasPartnerJoined() async throws(PairingFailure) -> Bool {
        partnerJoined
    }

    func end() async throws(PairingFailure) {}

    func endOtherPairs() async throws(PairingFailure) {}
}
