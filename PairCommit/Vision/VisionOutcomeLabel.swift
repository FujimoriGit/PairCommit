//
//  VisionOutcomeLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import SwiftUI

extension Vision.Outcome {
    var label: String {
        switch self {
        case .achieved: String(localized: .outcomeAchievedLabel)
        case .abandoned: String(localized: .outcomeAbandonedLabel)
        }
    }

    var result: String {
        switch self {
        case .achieved: String(localized: .outcomeAchievedResult)
        case .abandoned: String(localized: .outcomeAbandonedResult)
        }
    }

    var confirmation: String {
        switch self {
        case .achieved: String(localized: .outcomeAchievedConfirmation)
        case .abandoned: String(localized: .outcomeAbandonedConfirmation)
        }
    }

    var tint: Color {
        switch self {
        case .achieved: .green
        case .abandoned: .secondary
        }
    }
}
