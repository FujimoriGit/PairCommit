//
//  FailureReason.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/26
//

import CloudKit

/// 通信の失敗を、利用者が自分で手を打てる単位に分けたもの。
enum FailureReason: Equatable {
    case signedOutOfICloud
    case iCloudFull
    case iCloudBusy
    case offline
    case nearbyUnavailable
    case disconnected
    case unexpected

    init(_ error: any Error) {
        if error is MultipeerSessionError {
            self = .disconnected
            return
        }
        switch (error as? CKError)?.code {
        case .notAuthenticated, .accountTemporarilyUnavailable:
            self = .signedOutOfICloud
        case .quotaExceeded:
            self = .iCloudFull
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            self = .iCloudBusy
        case .networkUnavailable, .networkFailure:
            self = .offline
        default:
            self = .unexpected
        }
    }
}
