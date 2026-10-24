//
//  SavedKnownState.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import Foundation

public struct SavedKnownState: KnownStateKeeping {
    public init() {}

    public func lastKnown() -> PartnershipState? {
        guard let data = UserDefaults.standard.data(forKey: Self.key) else { return nil }
        do {
            return try JSONDecoder().decode(PartnershipState.self, from: data)
        } catch {
            Diagnostics.notification.failed("known state decode", error)
            return nil
        }
    }

    public func keep(_ state: PartnershipState) {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(state), forKey: Self.key)
        } catch {
            Diagnostics.notification.failed("known state encode", error)
        }
    }

    public func forget() {
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}

// MARK: - Private

private extension SavedKnownState {
    static let key = "partnership.knownState"
}
