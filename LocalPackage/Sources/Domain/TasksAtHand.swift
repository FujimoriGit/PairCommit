//
//  TasksAtHand.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Foundation

extension PartnershipState {
    /// 進行中のビジョンのタスクのうち、そのロールがいま手を動かすもの。期限の早い順。
    /// 見届ける人には、自分の番のタスクと、期限が過ぎた未完了のタスク。
    /// 挑む人には、期限が切れているか7日以内に来る未完了のタスク。
    public func tasksAtHand(for role: Role, now: Date, in calendar: Calendar) -> [TaskItem] {
        guard let vision = activeVision else { return [] }
        return tasks(for: vision.id)
            .filter { isAtHand($0, for: role, now: now, in: calendar) }
            .sortedByDeadline()
    }
}

extension Sequence<TaskItem> {
    /// 期限の早い順。期限の無いタスクは最後。
    public func sortedByDeadline() -> [TaskItem] {
        sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }
}

// MARK: - Private

private extension PartnershipState {
    func isAtHand(_ task: TaskItem, for role: Role, now: Date, in calendar: Calendar) -> Bool {
        let due = task.due(at: now, in: calendar)
        switch role {
        case .manager:
            return task.status.turn == .manager || (task.status == .todo && due == .overdue)
        case .player:
            return task.status == .todo && [.overdue, .today, .withinWeek].contains(due)
        }
    }
}
