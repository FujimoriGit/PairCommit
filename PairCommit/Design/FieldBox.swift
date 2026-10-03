//
//  FieldBox.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import SwiftUI

extension View {
    func fieldBox() -> some View {
        FieldBox { self }
    }
}

// MARK: - Private

private struct FieldBox<Content: View>: View {
    @ViewBuilder let content: Content

    @FocusState private var isFocused: Bool

    var body: some View {
        content
            .focused($isFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .modifier(FieldSurface())
            .contentShape(.rect)
            .onTapGesture { isFocused = true }
    }
}

private struct FieldSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content.background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
        }
    }
}
