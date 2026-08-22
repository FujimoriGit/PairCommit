//
//  NudgeMessage.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain

extension Nudge {
    func message(in state: PartnershipState) -> String {
        switch self {
        case .taskOverdue(let id): "「\(title(of: id, in: state))」の期限を過ぎています"
        case .taskDueSoon(let id): "「\(title(of: id, in: state))」の期限が近づいています"
        case .approvalStalled(let id): "「\(title(of: id, in: state))」の完了報告が承認されないままです"
        case .visionOverdue: "ビジョンの期限を過ぎています。達成できたか判断してください"
        }
    }
}

// MARK: - Private

private extension Nudge {
    func title(of id: TaskItem.ID, in state: PartnershipState) -> String {
        state.tasks.first { $0.id == id }?.title ?? "タスク"
    }
}
