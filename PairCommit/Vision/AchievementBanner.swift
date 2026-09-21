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
        VStack(alignment: .leading, spacing: 6) {
            Text("🎉 達成しました")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color(.deepGreen))
            Text(vision.statement)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .card()
    }
}
