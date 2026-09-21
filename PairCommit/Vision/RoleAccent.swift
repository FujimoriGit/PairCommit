//
//  RoleAccent.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/19
//

import Domain
import SwiftUI

extension Role {
    var accent: Color {
        switch self {
        case .manager: .indigo
        case .player: .cyan
        }
    }
}
