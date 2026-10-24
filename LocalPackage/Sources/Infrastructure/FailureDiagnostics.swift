//
//  FailureDiagnostics.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/24
//

import Domain

public struct FailureDiagnostics: FailureRecording {
    public init() {}

    public func record(_ failure: any Error, during operation: String) {
        Diagnostics.application.failed(operation, failure)
    }
}
