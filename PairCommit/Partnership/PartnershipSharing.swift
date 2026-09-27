//
//  PartnershipSharing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import Foundation

/// ペアを同期先に置き、2台で共有する。
protocol PartnershipSharing: Sendable {
    /// - Returns: 相手に渡す共有の URL と、作ったペア。
    func makeShare(initialState: PartnershipState) async throws -> (url: URL, outcome: PairingOutcome)
    func acceptShare(from url: URL) async throws -> PairingOutcome
    func makeSynchronizer(for outcome: PairingOutcome) -> any PartnershipSyncing
    func teardown(_ outcome: PairingOutcome) async throws
}
