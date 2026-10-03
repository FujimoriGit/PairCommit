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
        case .taskOverdue(let id): String(localized: "「\(title(of: id, in: state))」の期限を過ぎています", comment: "通知。%@ はタスク名")
        case .taskDueSoon(let id): dueSoonMessage(of: id, in: state)
        case .approvalStalled(let id): String(localized: "「\(title(of: id, in: state))」の完了報告が承認されないままです", comment: "通知。%@ はタスク名")
        case .visionOverdue: String(localized: "ビジョンの期限を過ぎています。達成できたか判断してください")
        }
    }
}

// MARK: - Private

private extension Nudge {
    func title(of id: TaskItem.ID, in state: PartnershipState) -> String {
        task(of: id, in: state)?.title ?? String(localized: "untitledTask", defaultValue: "Task")
    }

    func dueSoonMessage(of id: TaskItem.ID, in state: PartnershipState) -> String {
        guard let deadline = task(of: id, in: state)?.deadline else {
            return String(localized: "「\(title(of: id, in: state))」の期限を確かめてください", comment: "通知。%@ はタスク名")
        }
        return String(
            localized: "「\(title(of: id, in: state))」の期限は\(deadline.formatted(Date.FormatStyle.monthDay))です",
            comment: "通知。1つ目の %@ はタスク名、2つ目は期限の月日"
        )
    }

    func task(of id: TaskItem.ID, in state: PartnershipState) -> TaskItem? {
        state.tasks.first { $0.id == id }
    }
}
