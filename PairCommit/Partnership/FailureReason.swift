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
    case iCloudAccountUnverified
    case iCloudFull
    case iCloudBusy
    case offline
    case nearbyUnavailable
    case disconnected
    case partnerFailed
    case unexpected

    init(_ error: any Error) {
        if error is MultipeerSessionError {
            self = .disconnected
            return
        }
        let cloudError = error as? CKError
        switch cloudError?.code {
        case .partialFailure:
            let reasons = cloudError?.partialErrorsByItemID?.values.map { Self($0) } ?? []
            self = reasons.first { $0 != .unexpected } ?? .unexpected
        case .notAuthenticated:
            self = .signedOutOfICloud
        case .accountTemporarilyUnavailable:
            self = .iCloudAccountUnverified
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
