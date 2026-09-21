//
//  FailureNote.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import SwiftUI

struct FailureNote: View {
    let message: String?

    @ViewBuilder
    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Color(.deepRed))
                .card()
        }
    }
}
