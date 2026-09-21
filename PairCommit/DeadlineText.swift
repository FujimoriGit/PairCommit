//
//  DeadlineText.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import SwiftUI

struct DeadlineText: View {
    let deadline: Date?
    var now = Date()

    @ViewBuilder
    var body: some View {
        if let deadline {
            Text(deadline.formatted(Date.FormatStyle.monthDay))
                .marker(deadline < now ? .red : .secondary)
        }
    }
}
