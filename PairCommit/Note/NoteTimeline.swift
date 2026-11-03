//
//  NoteTimeline.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import SwiftUI

struct NoteTimeline: View {
    let notes: [Note]
    let pairing: Pairing?
    let role: Role

    var body: some View {
        SectionHeader(text: String(localized: .noteSection))
        if notes.isEmpty {
            Text(.noteEmpty)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        ForEach(notes) { note in
            row(note)
        }
    }
}

// MARK: - Private

private extension NoteTimeline {
    func row(_ note: Note) -> some View {
        let isMine = note.author == role
        return VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            HStack(spacing: 6) {
                if !isMine {
                    Text(author(of: note))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                kind(of: note)
            }
            .padding(.horizontal, 6)
            Text(AttributedString(linkingURLsIn: note.body))
                .font(.subheadline)
                .foregroundStyle(isMine ? .white : .primary)
                .tint(isMine ? .white : role.accent)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(isMine ? role.accent : Color(.secondarySystemGroupedBackground), in: bubble(isMine: isMine))
                .contentShape(.contextMenuPreview, bubble(isMine: isMine))
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = note.body
                    } label: {
                        Label(String(localized: .noteCopy), systemImage: "doc.on.doc")
                    }
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
    }

    func kind(of note: Note) -> some View {
        Text(note.kind.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(note.kind.tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(note.kind.tint.opacity(0.12), in: .capsule)
    }

    func bubble(isMine: Bool) -> UnevenRoundedRectangle {
        .rect(
            topLeadingRadius: 18,
            bottomLeadingRadius: isMine ? 18 : 6,
            bottomTrailingRadius: isMine ? 6 : 18,
            topTrailingRadius: 18
        )
    }

    func author(of note: Note) -> String {
        pairing?.name(of: note.author) ?? note.author.label
    }
}
