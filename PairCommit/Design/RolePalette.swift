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
        case .player: .deepTeal
        }
    }

    var symbol: String {
        switch self {
        case .manager: "binoculars.fill"
        case .player: "figure.run"
        }
    }
}

// MARK: - Private

private extension Color {
    // systemTeal も systemCyan も白地で 2.6:1 しかなく、tint はボタンの文字色になる。
    static let deepTeal = Color(red: 11 / 255, green: 114 / 255, blue: 133 / 255)
}
