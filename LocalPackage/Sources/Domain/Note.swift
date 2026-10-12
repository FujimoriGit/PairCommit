//
//  Note.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Foundation

/// ビジョンかタスクに、2人が書き残す短い文。書いたあとは書き直せない。
public struct Note: Identifiable, Sendable, Codable, Equatable {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case report
        case reminder
        case feedback
    }

    /// 承認や差し戻しをせずに書ける種類。状況報告は挑む人だけが、催促は見届ける人だけが書ける。フィードバックは、見届ける人が承認か差し戻しをするときにだけ書ける。
    public enum StandaloneKind: Sendable, CaseIterable {
        case report
        case reminder

        public var kind: Kind {
            switch self {
            case .report: .report
            case .reminder: .reminder
            }
        }
    }

    public enum Subject: Hashable, Sendable, Codable {
        case vision(Vision.ID)
        case task(TaskItem.ID)
    }

    public let id: UUID
    public let subject: Subject
    public let kind: Kind
    public let author: Role
    /// ペアの中での通しの番号。書いた順に1から振る。
    public let number: Int
    public let body: String
    public let writtenAt: Date

    public init(
        id: UUID,
        subject: Subject,
        kind: Kind,
        author: Role,
        number: Int,
        body: String,
        writtenAt: Date
    ) {
        self.id = id
        self.subject = subject
        self.kind = kind
        self.author = author
        self.number = number
        self.body = body
        self.writtenAt = writtenAt
    }
}
