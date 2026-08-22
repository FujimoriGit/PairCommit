//
//  AchievementBanner.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import SwiftUI

struct AchievementBanner: View {
    let vision: Vision

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("🎉 達成しました")
                    .font(.headline)
                Text(vision.statement)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}
