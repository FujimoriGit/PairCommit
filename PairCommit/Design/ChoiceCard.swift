//
//  ChoiceCard.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import SwiftUI

struct ChoiceCard: View {
    let symbol: String
    let title: String
    let summary: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(accent.gradient, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .card(outlined: accent.opacity(0.35))
    }
}
