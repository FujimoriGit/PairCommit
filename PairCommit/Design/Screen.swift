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
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Backdrop(colors: [role.accent]))
        .tint(role.accent)
    }
}
