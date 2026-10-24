//
//  RecordedFailures.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/24
//

import Domain
import Foundation

final class RecordedFailures: FailureRecording, @unchecked Sendable {
    private let lock = NSLock()
    private var failures: [any Error] = []

    var recorded: [any Error] {
        lock.withLock { failures }
    }

    func record(_ failure: any Error, during operation: String) {
        lock.withLock { failures.append(failure) }
    }
}
