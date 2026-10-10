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
    /// 名前が決まったときに呼ぶ。保存の途中では呼ばない。
    let onNamed: @MainActor () -> Void

    @State private var name: String
    @State private var failureMessage: String?
    @State private var isSaving = false

    init(store: PartnershipStore, onNamed: @escaping @MainActor () -> Void = {}) {
        self.store = store
        self.onNamed = onNamed
        _name = State(initialValue: store.state.pairing?.name(of: store.role) ?? "")
    }

    var body: some View {
        TextField(String(localized: .namingPlaceholder), text: $name)
            .textContentType(.nickname)
            .submitLabel(.done)
            .onSubmit(save)
            .fieldBox()
            .onChange(of: isNamed) { _, isNamed in
                if isNamed {
                    onNamed()
                }
            }
        Button(.namingSave, action: save)
            .buttonStyle(.filled)
            .disabled(!canSave)
        FailureNote(message: failureMessage)
    }
}

// MARK: - Private

private extension NamingForm {
    var savedName: String? {
        store.state.pairing?.name(of: store.role)
    }

    // 保存の途中の状態には名前が先に入っているので、それでは決まったとみなさない
    var isNamed: Bool {
        !isSaving && savedName != nil
    }

    var canSave: Bool {
        !isSaving && !name.isBlank && name != savedName
    }

    func save() {
        guard canSave else { return }
        let entered = name
        failureMessage = nil
        isSaving = true
        Task {
            defer { isSaving = false }
            do throws(PartnershipFailure) {
                try await store.perform { state, role throws(DomainError) in
                    try state.naming(entered, by: role)
                }
                name = savedName ?? entered
            } catch {
                failureMessage = error.message
            }
        }
    }
}

struct NamingScreen: View {
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
    NamingScreen(store: .preview(role: .player, visions: [], named: false))
}
