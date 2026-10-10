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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(author(of: note))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(note.kind.label)
                    .marker(.secondary)
                Spacer(minLength: 8)
                Text(note.writtenAt, format: Date.FormatStyle.monthDayTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(note.body)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    func author(of note: Note) -> String {
        guard note.author != role else { return String(localized: .noteYou) }
        return pairing?.name(of: note.author) ?? note.author.label
    }
}
