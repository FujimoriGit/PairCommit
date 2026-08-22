//
//  PartnershipFailure.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain

public enum PartnershipFailure: Error, Equatable, Sendable {
    case rejected(DomainError)
    case notSynchronized(SyncFailure)
}
