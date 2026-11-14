//
//  SavedUnseen.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Domain
import Foundation

public struct SavedUnseen: UnseenKeeping {
    public init() {}

    public func lastUnseen() -> UnseenUpdates {
        guard let data = UserDefaults.standard.data(forKey: Self.key) else { return .init() }
        do {
            return try JSONDecoder().decode(UnseenUpdates.self, from: data)
        } catch {
            Diagnostics.notification.failed("unseen decode", error)
            return .init()
        }
    }

    public func keep(_ unseen: UnseenUpdates) {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(unseen), forKey: Self.key)
        } catch {
            Diagnostics.notification.failed("unseen encode", error)
        }
    }
}

// MARK: - Private

private extension SavedUnseen {
    static let key = "partnership.unseen"
}
