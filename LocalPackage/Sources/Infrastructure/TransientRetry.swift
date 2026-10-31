//
//  TransientRetry.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/31
//

import CloudKit
import Domain
import Foundation

/// iCloud が一時的に通さなかった操作を、示された時間だけ待って1回やり直す。
/// 示された時間が長すぎるときは、やり直さずにそのまま投げる。
enum TransientRetry {
    static func run<Value>(_ operation: String, _ body: () async throws -> Value) async throws -> Value {
        do {
            return try await body()
        } catch {
            guard let delay = retryDelay(after: error) else { throw error }
            Diagnostics.pairing.failed("\(operation) を \(delay) 秒後にやり直す", error)
            try await Task.sleep(for: .seconds(delay))
            return try await body()
        }
    }
}

// MARK: - Private

private extension TransientRetry {
    static let defaultDelay: TimeInterval = 2
    static let longestDelay: TimeInterval = 5

    static func retryDelay(after error: any Error) -> TimeInterval? {
        switch PairingFailure.classifying(error) {
        case .offline, .serverBusy:
            let delay = suggestedDelay(of: error) ?? defaultDelay
            return delay <= longestDelay ? delay : nil
        default:
            return nil
        }
    }

    static func suggestedDelay(of error: any Error) -> TimeInterval? {
        guard let cloudError = error as? CKError else { return nil }
        if let seconds = cloudError.retryAfterSeconds {
            return seconds
        }
        return cloudError.partialErrorsByItemID?.values.compactMap(suggestedDelay).max()
    }
}
