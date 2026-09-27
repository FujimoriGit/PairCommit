//
//  SymbolBadge.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import SwiftUI

struct SymbolBadge: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 42, weight: .light))
            .foregroundStyle(.tint)
            .frame(width: 96, height: 96)
            .background(Color(.secondarySystemGroupedBackground), in: .circle)
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            .accessibilityHidden(true)
    }
}
