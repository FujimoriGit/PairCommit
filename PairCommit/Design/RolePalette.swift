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

    /// ビジョンのカードをガラスにするときの、色の濃淡の明るい側。
    func glassHighlight(in environment: EnvironmentValues) -> Color {
        let (hueShift, brightnessScale): (CGFloat, CGFloat) = switch self {
        case .manager: (0.06, 0.75)
        case .player: (0.06, 1.15)
        }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(cgColor: accent.resolve(in: environment).cgColor)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(
            hue: (hue + hueShift).truncatingRemainder(dividingBy: 1),
            saturation: saturation,
            brightness: min(brightness * brightnessScale, 1)
        )
    }

    var symbol: String {
        switch self {
        case .manager: "binoculars.fill"
        case .player: "figure.run"
        }
    }
}
