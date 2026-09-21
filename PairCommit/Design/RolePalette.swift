//
//  RolePalette.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import Domain
import SwiftUI

extension Role {
    var accent: Color {
        switch self {
        case .manager: .indigo
        case .player: Color(.playerAccent)
        }
    }

    var symbol: String {
        switch self {
        case .manager: "binoculars.fill"
        case .player: "figure.run"
        }
    }
}
