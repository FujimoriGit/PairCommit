//
//  CountBadge.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import SwiftUI

/// まだ見ていない更新の数を出す赤い丸。
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(count, format: .number)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(.red, in: .capsule)
            .accessibilityLabel(Text(.unseenCount(count)))
    }
}
