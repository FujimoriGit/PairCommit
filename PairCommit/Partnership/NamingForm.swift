//
//  NamingForm.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import SwiftUI

struct NamingForm: View {
    let store: PartnershipStore
    let onSaved: @MainActor () -> Void

    @State private var name: String
    @State private var failureMessage: String?

    init(store: PartnershipStore, onSaved: @escaping @MainActor () -> Void = {}) {
        self.store = store
        self.onSaved = onSaved
        _name = State(initialValue: store.state.pairing?.name(of: store.role) ?? "")
    }

    var body: some View {
        TextField(String(localized: .namingPlaceholder), text: $name)
            .textContentType(.nickname)
            .submitLabel(.done)
            .onSubmit(save)
            .fieldBox()
        Button(.namingSave, action: save)
            .buttonStyle(.filled)
            .disabled(!canSave)
        FailureNote(message: failureMessage)
    }
}

// MARK: - Private

private extension NamingForm {
    var canSave: Bool {
        !name.isBlank && name != store.state.pairing?.name(of: store.role)
    }

    func save() {
        guard canSave else { return }
        let entered = name
        failureMessage = nil
        Task {
            do throws(PartnershipFailure) {
                try await store.perform { state, role throws(DomainError) in
                    try state.naming(entered, by: role)
                }
                name = store.state.pairing?.name(of: store.role) ?? entered
                onSaved()
            } catch {
                failureMessage = error.message
            }
        }
    }
}

struct NamingSheet: View {
    let store: PartnershipStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                    SymbolBadge(symbol: "person.crop.circle")

                    VStack(spacing: 10) {
                        Text(.namingTitle)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text(.namingMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        NamingForm(store: store) { dismiss() }
                    }
                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Backdrop(colors: [store.role.accent]))
        .tint(store.role.accent)
    }
}

#Preview("呼び名の入力") {
    NamingSheet(store: .preview(role: .player, visions: [], named: false))
}
