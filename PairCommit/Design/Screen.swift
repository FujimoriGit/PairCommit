//
//  Screen.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import Domain
import SwiftUI

struct Screen<Content: View>: View {
    let role: Role
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Backdrop(colors: [role.accent]))
        .tint(role.accent)
    }
}

// MARK: - Private

private extension Screen {
    var header: some View {
        HStack(spacing: 12) {
            Image(systemName: role.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(role.accent.gradient, in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(role.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(role.accent)
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }
}
