//
//  Note.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Foundation

/// ビジョンかタスクに、2人が書き残す短い文。書いたあとは書き直せない。
public struct Note: Identifiable, Sendable, Equatable {
    public enum Kind: Hashable, Sendable {
        case report
        case reminder
        /// 見届ける人が承認・差し戻しに添えた言葉。どちらの判断かを残す前の版のアプリで書いたものは nil。
        case feedback(Judgment?)
    }

    public enum Judgment: String, Sendable, Codable {
        case approved
        case returned
    }

    /// 見届ける人が、いま効いている判断に添えた言葉。
    public struct Feedback: Equatable, Sendable {
        public let judgment: Judgment
        public let body: String
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

extension Note {
    var isFeedback: Bool {
        if case .feedback = kind { true } else { false }
    }
}

extension Note: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind: Kind = switch try container.decode(KindName.self, forKey: .kind) {
        case .report: .report
        case .reminder: .reminder
        case .feedback: .feedback(try container.decodeIfPresent(Judgment.self, forKey: .judgment))
        }
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            subject: try container.decode(Subject.self, forKey: .subject),
            kind: kind,
            author: try container.decode(Role.self, forKey: .author),
            number: try container.decode(Int.self, forKey: .number),
            body: try container.decode(String.self, forKey: .body),
            writtenAt: try container.decode(Date.self, forKey: .writtenAt)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(subject, forKey: .subject)
        switch kind {
        case .report:
            try container.encode(KindName.report, forKey: .kind)
        case .reminder:
            try container.encode(KindName.reminder, forKey: .kind)
        case .feedback(let judgment):
            try container.encode(KindName.feedback, forKey: .kind)
            try container.encodeIfPresent(judgment, forKey: .judgment)
        }
        try container.encode(author, forKey: .author)
        try container.encode(number, forKey: .number)
        try container.encode(body, forKey: .body)
        try container.encode(writtenAt, forKey: .writtenAt)
    }
}

// MARK: - Private

private extension Note {
    enum CodingKeys: String, CodingKey {
        case id
        case subject
        case kind
        case judgment
        case author
        case number
        case body
        case writtenAt
    }

    enum KindName: String, Codable {
        case report
        case reminder
        case feedback
    }
}
