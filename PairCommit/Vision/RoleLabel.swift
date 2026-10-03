//
//  RoleLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain
import Foundation

extension Role {
    var label: String {
        switch self {
        case .manager: String(localized: .roleManagerName)
        case .player: String(localized: .rolePlayerName)
        }
    }

    var summary: String {
        switch self {
        case .manager: String(localized: .roleManagerSummary)
        case .player: String(localized: .rolePlayerSummary)
        }
    }
}
