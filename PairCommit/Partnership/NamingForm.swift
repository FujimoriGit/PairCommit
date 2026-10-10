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
