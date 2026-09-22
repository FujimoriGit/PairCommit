//
//  Card.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import SwiftUI

extension View {
    func card(tinted tint: Color? = nil, outlined outline: Color? = nil) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(tint?.opacity(0.18) ?? .clear, in: .rect(cornerRadius: cardCornerRadius))
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: cardCornerRadius))
            .overlay {
                if let outline {
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .strokeBorder(outline, lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

// MARK: - Private

private let cardCornerRadius: CGFloat = 20
