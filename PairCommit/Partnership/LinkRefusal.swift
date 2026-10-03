//
//  LinkRefusal.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Foundation

/// 招待リンクを開いても参加しない理由。
enum LinkRefusal: Sendable {
    case alreadyPaired
    case pairingInProgress

    var title: String {
        switch self {
        case .alreadyPaired: String(localized: .linkRefusalAlreadyPairedTitle)
        case .pairingInProgress: String(localized: .linkRefusalPairingInProgressTitle)
        }
    }

    var message: String {
        switch self {
        case .alreadyPaired: String(localized: .linkRefusalAlreadyPairedMessage)
        case .pairingInProgress: String(localized: .linkRefusalPairingInProgressMessage)
        }
    }
}
