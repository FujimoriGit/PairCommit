//
//  VisionDetail.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import Domain
import SwiftUI

struct VisionDetail: View {
    let vision: Vision
    var note: String?
    var noteTint: Color = .orange

    var body: some View {
        Panel {
            if let note {
                Text(note)
                    .marker(noteTint)
            }
            Text(vision.statement)
                .font(.system(.title3, design: .rounded, weight: .bold))
            field(String(localized: .commonDoneCriteria), vision.doneCriteria)
            if let why = vision.why {
                field(String(localized: .commonWhy), why)
            }
            field(String(localized: .commonDeadline), deadline)
        }
    }
}

// MARK: - Private

private extension VisionDetail {
    var deadline: String {
        vision.deadline.map { $0.formatted(Date.FormatStyle.yearMonthDay) } ?? String(localized: .commonNoDeadline)
    }

    func field(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}
