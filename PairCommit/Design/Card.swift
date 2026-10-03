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
            .modifier(CardSurface(tint: tint, outline: outline))
    }
}

// MARK: - Private

private let cardCornerRadius: CGFloat = 20

private struct CardSurface: ViewModifier {
    let tint: Color?
    let outline: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.tint(tint?.opacity(0.18)), in: .rect(cornerRadius: cardCornerRadius))
                .overlay { border }
        } else {
            content
                .background(tint?.opacity(0.18) ?? .clear, in: .rect(cornerRadius: cardCornerRadius))
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: cardCornerRadius))
                .overlay { border }
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
    }
}

private extension CardSurface {
    @ViewBuilder
    var border: some View {
        if let outline {
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .strokeBorder(outline, lineWidth: 1)
        }
    }
}
