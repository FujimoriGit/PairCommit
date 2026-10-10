//
//  NoteSection.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import SwiftUI

struct NoteSection: View {
    let store: PartnershipStore
    let subject: Note.Subject

    @State private var kind: Note.Kind
    @State private var text = ""
    @State private var isPosting = false
    @State private var failureMessage: String?

    init(store: PartnershipStore, subject: Note.Subject) {
        self.store = store
        self.subject = subject
        _kind = .init(initialValue: store.role == .player ? .report : .reminder)
    }

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
        composer
            .sensoryFeedback(.error, trigger: failureMessage) { _, message in message != nil }
        FailureNote(message: failureMessage)
    }
}

// MARK: - Private

private extension NoteSection {
    var notes: [Note] {
        store.state.notes(on: subject)
    }

    func row(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.state.pairing?.name(of: note.author) ?? note.author.label)
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

    var composer: some View {
        Panel {
            Picker(String(localized: .noteSection), selection: $kind) {
                ForEach(Note.Kind.allCases.filter { $0.isWritable(by: store.role) }, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            TextField(String(localized: .notePlaceholder), text: $text, axis: .vertical)
                .lineLimit(2...5)
                .fieldBox()
            Button(.notePost, action: post)
                .buttonStyle(.filled)
                .disabled(text.isBlank || isPosting)
        }
    }

    func post() {
        let body = text
        let kind = kind
        let subject = subject
        isPosting = true
        Task {
            defer { isPosting = false }
            do throws(PartnershipFailure) {
                try await store.perform { state, role throws(DomainError) in
                    try state.writingNote(body, kind: kind, on: subject, by: role)
                }
                text = ""
                failureMessage = nil
            } catch {
                failureMessage = error.message
            }
        }
    }
}
