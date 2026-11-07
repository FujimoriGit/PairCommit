//
//  NotificationSubject.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/07
//

import Domain
import Foundation

extension Note.Subject {
    /// 押された通知の `userInfo` から、その通知の対象を読む。対象を載せていない通知なら nil。
    public init?(notificationUserInfo userInfo: [AnyHashable: Any]) {
        guard let kind = userInfo[Self.kindKey] as? String,
              let id = (userInfo[Self.idKey] as? String).flatMap(UUID.init(uuidString:)) else { return nil }
        switch kind {
        case Self.visionKind: self = .vision(id)
        case Self.taskKind: self = .task(id)
        default: return nil
        }
    }

    var notificationUserInfo: [AnyHashable: Any] {
        switch self {
        case .vision(let id): [Self.kindKey: Self.visionKind, Self.idKey: id.uuidString]
        case .task(let id): [Self.kindKey: Self.taskKind, Self.idKey: id.uuidString]
        }
    }
}

// MARK: - Private

private extension Note.Subject {
    static let kindKey = "subject"
    static let idKey = "subjectID"
    static let visionKind = "vision"
    static let taskKind = "task"
}
