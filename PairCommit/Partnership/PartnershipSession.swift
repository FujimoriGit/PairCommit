//
//  PartnershipSession.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/05
//

import Application
import Observation

/// ペアが成立してからの状態。
@MainActor
@Observable
final class PartnershipSession {
    var store: PartnershipStore?
}
