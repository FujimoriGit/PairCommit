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
        case .taskDueSoon(let id): "「\(title(of: id, in: state))」の期限は\(deadline(of: id, in: state))です"
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

    func deadline(of id: TaskItem.ID, in state: PartnershipState) -> String {
        state.tasks.first { $0.id == id }?.deadline?.formatted(Date.FormatStyle.monthDay) ?? "間もなく"
    }
}
