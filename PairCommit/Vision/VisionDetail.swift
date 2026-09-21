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
                Chip(text: note, tint: noteTint)
            }
            Text(vision.statement)
                .font(.system(.title3, design: .rounded, weight: .bold))
            field("達成基準", vision.doneCriteria)
            if let deadline = vision.deadline {
                field("期限", deadline.formatted(Date.FormatStyle.yearMonthDay))
            }
        }
    }
}

// MARK: - Private

private extension VisionDetail {
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
