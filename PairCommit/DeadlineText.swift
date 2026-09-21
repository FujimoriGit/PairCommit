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
            Chip(
                text: deadline.formatted(Date.FormatStyle.monthDay),
                tint: deadline < now ? .red : .secondary
            )
        }
    }
}
