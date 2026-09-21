//
//  Card.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import SwiftUI

extension View {
    func card(tinted tint: Color? = nil) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(tint?.opacity(0.18) ?? .clear, in: .rect(cornerRadius: 20))
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}
