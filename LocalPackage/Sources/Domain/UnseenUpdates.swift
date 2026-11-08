//
//  UnseenUpdates.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Foundation

/// 相手が自分に向けて行った操作のうち、この端末でまだ開いて見ていないもの。対象ごとの件数で持つ。
public struct UnseenUpdates: Hashable, Sendable, Codable {
    public let counts: [Note.Subject: Int]

    public init(counts: [Note.Subject: Int] = [:]) {
        self.counts = counts
    }

    public var total: Int {
        counts.values.reduce(0, +)
    }

    public func count(on subject: Note.Subject) -> Int {
        counts[subject] ?? 0
    }

    public func adding(_ actions: [PartnerAction]) -> Self {
        .init(counts: actions.reduce(into: counts) { $0[$1.subject, default: 0] += 1 })
    }

    public func seeing(_ subjects: Set<Note.Subject>) -> Self {
        .init(counts: counts.filter { !subjects.contains($0.key) })
    }

    /// `state` に残っていない対象（取り下げた起案など）の件数を外す。
    public func keeping(in state: PartnershipState) -> Self {
        .init(counts: counts.filter { state.contains($0.key) })
    }
}

// MARK: - Private

private extension PartnershipState {
    func contains(_ subject: Note.Subject) -> Bool {
        switch subject {
        case .vision(let id): visions.contains { $0.id == id }
        case .task(let id): tasks.contains { $0.id == id }
        }
    }
}
