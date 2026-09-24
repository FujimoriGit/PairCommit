//
//  NudgeMessage.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import Foundation

extension Nudge {
    func message(in state: PartnershipState) -> String {
        switch self {
        case .taskOverdue(let id): "「\(title(of: id, in: state))」の期限を過ぎています"
        case .taskDueSoon(let id): dueSoonMessage(of: id, in: state)
        case .approvalStalled(let id): "「\(title(of: id, in: state))」の完了報告が承認されないままです"
        case .visionOverdue: "ビジョンの期限を過ぎています。達成できたか判断してください"
        }
    }
}

// MARK: - Private

private extension Nudge {
    func title(of id: TaskItem.ID, in state: PartnershipState) -> String {
        task(of: id, in: state)?.title ?? "タスク"
    }

    func dueSoonMessage(of id: TaskItem.ID, in state: PartnershipState) -> String {
        guard let deadline = task(of: id, in: state)?.deadline else {
            return "「\(title(of: id, in: state))」の期限を確かめてください"
        }
        return "「\(title(of: id, in: state))」の期限は\(deadline.formatted(Date.FormatStyle.monthDay))です"
    }

    func task(of id: TaskItem.ID, in state: PartnershipState) -> TaskItem? {
        state.tasks.first { $0.id == id }
    }
}
