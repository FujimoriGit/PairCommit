//
//  NoteComposer.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import SwiftUI

struct NoteComposer: View {
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
        VStack(alignment: .leading, spacing: 10) {
            Picker(String(localized: .noteSection), selection: $kind) {
                ForEach(Note.Kind.allCases.filter { $0.isWritable(by: store.role) }, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            HStack(alignment: .bottom, spacing: 10) {
                TextField(String(localized: .notePlaceholder), text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .fieldBox()
                Button(action: post) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.largeTitle)
                }
                .disabled(text.isBlank || isPosting)
                .accessibilityLabel(Text(.notePost))
            }
            if let failureMessage {
                Label(failureMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.default, value: failureMessage)
        .sensoryFeedback(.error, trigger: failureMessage) { _, message in message != nil }
    }
}

// MARK: - Private

private extension NoteComposer {
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
