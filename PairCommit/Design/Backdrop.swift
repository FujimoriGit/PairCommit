//
//  Backdrop.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import Domain
import SwiftUI

struct Backdrop: View {
    var colors: [Color] = Role.allCases.map(\.accent)

    var body: some View {
        LinearGradient(
            colors: colors.map { $0.opacity(0.2) } + [Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .center
        )
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea()
    }
}
