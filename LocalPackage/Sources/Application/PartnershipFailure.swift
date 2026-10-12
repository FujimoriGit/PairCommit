//
//  PartnershipFailure.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain

public enum PartnershipFailure<Rejection: Error>: Error {
    case rejected(Rejection)
    case notSynchronized(SyncFailure)
}

extension PartnershipFailure: Equatable where Rejection: Equatable {}
