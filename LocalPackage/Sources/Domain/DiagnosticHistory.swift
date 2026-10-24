//
//  DiagnosticHistory.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/24
//

import Foundation

/// 端末に残した、失敗と判断の記録。
public protocol DiagnosticHistory: Sendable {
    /// - Returns: 新しい順。
    func recentEntries() -> [DiagnosticEntry]
}

public struct DiagnosticEntry: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let occurredAt: Date
    public let isFailure: Bool
    public let operation: String
    public let detail: String

    public init(id: UUID, occurredAt: Date, isFailure: Bool, operation: String, detail: String) {
        self.id = id
        self.occurredAt = occurredAt
        self.isFailure = isFailure
        self.operation = operation
        self.detail = detail
    }
}
