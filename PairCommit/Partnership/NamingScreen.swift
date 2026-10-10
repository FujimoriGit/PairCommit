//
//  NamingScreen.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import SwiftUI

struct NamingScreen: View {
    let store: PartnershipStore

    @State private var name = ""
    @State private var failureMessage: String?
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(.namingTitle)
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text(.namingMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                TextField(String(localized: .namingPlaceholder), text: $name)
                    .textContentType(.nickname)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .fieldBox()
                if let failureMessage {
                    Label(failureMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(.namingSave, action: save)
                .buttonStyle(.filled)
                .disabled(!canSave)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .background(Backdrop(colors: [store.role.accent]))
        .tint(store.role.accent)
        .animation(.default, value: failureMessage)
        .sensoryFeedback(.error, trigger: failureMessage) { _, message in message != nil }
        .onChange(of: isNamed) { _, isNamed in
            if isNamed {
                dismiss()
            }
        }
    }
}

// MARK: - Private

private extension NamingScreen {
    // 保存の途中の状態には名前が先に入っているので、それでは決まったとみなさない
    var isNamed: Bool {
        !isSaving && store.ownName != nil
    }

    var canSave: Bool {
        !isSaving && !name.isBlank
    }

    func save() {
        guard canSave else { return }
        let entered = name
        failureMessage = nil
        isSaving = true
        Task {
            failureMessage = await store.saveName(entered)
            isSaving = false
        }
    }
}

#Preview("呼び名の入力") {
    NamingScreen(store: .preview(role: .player, visions: [], named: false))
}
