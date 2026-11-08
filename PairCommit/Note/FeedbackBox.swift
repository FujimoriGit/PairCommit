//
//  FeedbackBox.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Domain
import SwiftUI

struct FeedbackBox: View {
    let feedback: Note.Feedback

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(feedback.judgment.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(feedback.judgment.tint)
            Text(AttributedString(linkingURLsIn: feedback.body))
                .font(.subheadline)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(feedback.judgment.tint.opacity(0.14), in: .rect(cornerRadius: 12))
    }
}

// MARK: - Private

private extension Note.Judgment {
    var title: String {
        switch self {
        case .approved: String(localized: .feedbackApproved)
        case .returned: String(localized: .feedbackReturned)
        }
    }

    var tint: Color {
        switch self {
        case .approved: .green
        case .returned: .orange
        }
    }
}
