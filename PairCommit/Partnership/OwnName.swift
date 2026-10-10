//
//  OwnName.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain

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
