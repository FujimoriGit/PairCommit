//
//  Haptic.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import UIKit

/// 鳴らした画面がすぐ消えても鳴る振動。
enum Haptic {
    case impact
    case lightImpact
    case selection
    case success
    case warning

    @MainActor
    func play() {
        switch self {
        case .impact: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .lightImpact: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}
