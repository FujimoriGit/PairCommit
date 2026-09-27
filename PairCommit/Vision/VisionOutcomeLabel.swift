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
        case .achieved: String(localized: "達成した")
        case .abandoned: String(localized: "取りやめる")
        }
    }

    var result: String {
        switch self {
        case .achieved: String(localized: "達成")
        case .abandoned: String(localized: "取りやめ")
        }
    }

    var confirmation: String {
        switch self {
        case .achieved: String(localized: "達成にする")
        case .abandoned: String(localized: "取りやめにする")
        }
    }

    var tint: Color {
        switch self {
        case .achieved: .green
        case .abandoned: .secondary
        }
    }
}
