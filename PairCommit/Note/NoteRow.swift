//
//  NoteRow.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Domain
import SwiftUI

struct NoteRow: View {
    let note: Note
    let pairing: Pairing?
    let role: Role
    let linkPreviewing: any LinkPreviewing

    @State private var preview: LinkPreview?

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            if !isMine || isFeedback {
                HStack(spacing: 6) {
                    if !isMine {
                        Text(author)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    if isFeedback {
                        Text(.noteKindFeedback)
                            .marker(.secondary)
                    }
                }
                .padding(.horizontal, 6)
            }
            Text(AttributedString(linkingURLsIn: note.body))
                .font(.subheadline)
                .foregroundStyle(isMine ? .white : .primary)
                .tint(isMine ? .white : role.accent)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(isMine ? role.accent : Color(.secondarySystemGroupedBackground), in: bubble)
                .textSelection(.enabled)
            if let link, let preview {
                LinkPreviewCard(url: link, preview: preview)
            }
            Text(note.writtenAt, format: Date.FormatStyle.monthDayTime)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
        }
        .padding(isMine ? .leading : .trailing, 56)
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel { label in
            if isMine {
                Text(.noteYou)
            }
            label
        }
        .animation(.default, value: preview)
        .task(id: link) { await loadPreview() }
    }
}

// MARK: - Private

private extension NoteRow {
    var isMine: Bool {
        note.author == role
    }

    var isFeedback: Bool {
        if case .feedback = note.kind { true } else { false }
    }

    var author: String {
        pairing?.name(of: note.author) ?? note.author.label
    }

    var bubble: UnevenRoundedRectangle {
        .rect(
            topLeadingRadius: 18,
            bottomLeadingRadius: isMine ? 18 : 6,
            bottomTrailingRadius: isMine ? 6 : 18,
            topTrailingRadius: 18
        )
    }

    var link: URL? {
        AttributedString(linkingURLsIn: note.body).runs
            .compactMap { $0.link }
            .first { ["http", "https"].contains($0.scheme?.lowercased()) }
    }

    func loadPreview() async {
        guard let link else { return }
        do throws(LinkPreviewFailure) {
            preview = try await linkPreviewing.preview(of: link)
        } catch {
            preview = nil
        }
    }
}
