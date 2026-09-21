//
//  SectionHeader.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import SwiftUI

struct SectionHeader: View {
    let text: String

    var body: some View {
        Text(text)
            .sectionTitle()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

extension View {
    func sectionTitle() -> some View {
        font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(.secondary)
    }
}
