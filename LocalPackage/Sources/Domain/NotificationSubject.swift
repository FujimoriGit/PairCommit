//
//  NotificationSubject.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/16
//

import Foundation

/// 通知が指しているもの。
public enum NotificationSubject: Hashable, Sendable {
    case task(TaskItem.ID)
    case vision(Vision.ID)
    /// そのビジョンのタスクの一覧。
    case tasks(of: Vision.ID)

    public init(_ subject: Note.Subject) {
        switch subject {
        case .task(let id): self = .task(id)
        case .vision(let id): self = .vision(id)
        }
    }
}
