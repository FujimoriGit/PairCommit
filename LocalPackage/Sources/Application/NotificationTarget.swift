//
//  NotificationTarget.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Domain
import Foundation

/// 押された通知の対象を開く先。
public enum NotificationTarget: Hashable, Sendable {
    /// ホームの上に重ねて開く画面。
    public enum Detail: Hashable, Sendable {
        case task(TaskItem.ID)
        case activeVision(Vision.ID)
        case closedVision(Vision.ID)
    }

    /// 対象がホームの最初の画面に出ている。提出されたビジョンと差し戻されたビジョン。
    case home
    case detail(Detail)
}

extension PartnershipState {
    /// 押された通知の対象を開く先。対象が見つからなければ nil。
    public func target(of subject: Note.Subject) -> NotificationTarget? {
        switch subject {
        case .task(let id):
            return tasks.contains { $0.id == id } ? .detail(.task(id)) : nil
        case .vision(let id):
            guard let vision = visions.first(where: { $0.id == id }) else { return nil }
            switch vision.status {
            case .active: return .detail(.activeVision(id))
            case .achieved, .abandoned: return .detail(.closedVision(id))
            case .draft, .proposed: return .home
            }
        }
    }
}
