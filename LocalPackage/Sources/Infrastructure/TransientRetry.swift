//
//  TransientRetry.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/31
//

import CloudKit
import Foundation

/// iCloud が一時的に通さなかった操作を、示された時間だけ待ってからやり直す。
enum TransientRetry {
    static func run<Value>(_ operation: String, _ body: () async throws -> Value) async throws -> Value {
        for _ in 1..<attempts {
            do {
                return try await body()
            } catch let error as CKError where transientCodes.contains(error.code) {
                Diagnostics.pairing.failed("\(operation) をやり直す", error)
                try await Task.sleep(for: .seconds(error.retryAfterSeconds ?? defaultDelay))
            }
        }
        return try await body()
    }
}

// MARK: - Private

private extension TransientRetry {
    static let attempts = 3
    static let defaultDelay: TimeInterval = 2
    static let transientCodes: Set<CKError.Code> = [.networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy]
}
