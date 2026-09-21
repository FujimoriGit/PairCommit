//
//  ReactionTint.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import SwiftUI

extension Reaction {
    var tint: Color {
        switch self {
        case .angry: .red
        case .uneasy: .orange
        case .happy: .green
        }
    }
}
