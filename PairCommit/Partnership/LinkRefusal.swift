//
//  LinkRefusal.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Application
import Foundation

extension PartnershipSession.LinkRefusal {
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
