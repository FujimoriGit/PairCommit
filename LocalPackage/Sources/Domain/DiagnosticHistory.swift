//
//  DiagnosticHistory.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/24
//

import Foundation

/// 端末に残した記録。
public protocol DiagnosticHistory: Sendable {
    /// - Returns: 新しい順。
    func recentEntries() -> [DiagnosticEntry]
}

public struct DiagnosticEntry: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        case failure
        case decision
        case progress
    }

    public let id: UUID
    public let occurredAt: Date
    public let kind: Kind
    public let operation: String
    public let detail: String

    public init(id: UUID, occurredAt: Date, kind: Kind, operation: String, detail: String) {
        self.id = id
        self.occurredAt = occurredAt
        self.kind = kind
        self.operation = operation
        self.detail = detail
    }
}
