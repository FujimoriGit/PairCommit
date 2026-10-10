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

    @State private var name: String
    @State private var failureMessage: String?
    @State private var isSaving = false

    init(store: PartnershipStore) {
        self.store = store
        _name = State(initialValue: store.ownName ?? "")
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

extension PartnershipStore {
    var ownName: String? {
        state.pairing?.name(of: role)
    }

    /// 失敗したときは、画面に出す文を返す。
    func saveName(_ name: String) async -> String? {
        do throws(PartnershipFailure) {
            try await perform { state, role throws(DomainError) in
                try state.naming(name, by: role)
            }
            return nil
        } catch {
            return error.message
        }
    }
}

// MARK: - Private

private extension NamingForm {
    var canSave: Bool {
        !isSaving && !name.isBlank && name != store.ownName
    }

    func save() {
        guard canSave else { return }
        let entered = name
        failureMessage = nil
        isSaving = true
        Task {
            failureMessage = await store.saveName(entered)
            if failureMessage == nil {
                name = store.ownName ?? entered
            }
            isSaving = false
        }
    }
}
