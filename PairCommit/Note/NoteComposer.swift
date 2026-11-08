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

    @State private var text = ""
    @State private var isPosting = false
    @State private var failureMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField(String(localized: .notePlaceholder), text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .padding(.leading, 14)
                    .padding(.vertical, 9)
                Button(action: post) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(isPostable ? store.role.accent : Color(.systemGray3), in: .circle)
                }
                .disabled(!isPostable)
                .accessibilityLabel(Text(.notePost))
                .padding(4)
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            }
            .contentShape(.rect)
            .onTapGesture { isFocused = true }
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
    var isPostable: Bool {
        !text.isBlank && !isPosting
    }

    func post() {
        let body = text
        let subject = subject
        text = ""
        isPosting = true
        Task {
            defer { isPosting = false }
            do throws(PartnershipFailure<NoteWritingError>) {
                try await store.perform { state, role throws(NoteWritingError) in
                    try state.writingNote(body, on: subject, by: role)
                }
                failureMessage = nil
            } catch {
                if text.isBlank {
                    text = body
                }
                failureMessage = error.message
            }
        }
    }
}
