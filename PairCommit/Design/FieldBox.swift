//
//  FieldBox.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import SwiftUI

extension View {
    func fieldBox() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
    }
}
