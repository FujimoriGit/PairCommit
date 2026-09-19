//
//  ReactionTint.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import SwiftUI

extension Reaction {
    var rowBackground: Color {
        tint.opacity(0.15)
    }
}

// MARK: - Private

private extension Reaction {
    var tint: Color {
        switch self {
        case .angry: .red
        case .uneasy: .orange
        case .happy: .green
        }
    }
}
