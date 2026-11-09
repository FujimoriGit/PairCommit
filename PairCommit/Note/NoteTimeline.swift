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
    let linkPreviewing: any LinkPreviewing

    var body: some View {
        SectionHeader(text: String(localized: .noteSection))
        if notes.isEmpty {
            Text(.noteEmpty)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        ForEach(notes) { note in
            NoteRow(note: note, pairing: pairing, role: role, linkPreviewing: linkPreviewing)
        }
    }
}
