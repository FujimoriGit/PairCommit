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
        case .taskOverdue(let id): String(localized: .nudgeTaskOverdue(title(of: id, in: state)))
        case .taskDueSoon(let id): dueSoonMessage(of: id, in: state)
        case .approvalStalled(let id): String(localized: .nudgeApprovalStalled(title(of: id, in: state)))
        case .visionOverdue: String(localized: .nudgeVisionOverdue)
        case .progressReportDue: String(localized: .nudgeProgressReportDue(name(of: .manager, in: state)))
        case .checkInDue: String(localized: .nudgeCheckInDue(name(of: .player, in: state)))
        }
    }
}

// MARK: - Private

private extension Nudge {
    func title(of id: TaskItem.ID, in state: PartnershipState) -> String {
        task(of: id, in: state)?.title ?? String(localized: .nudgeUntitledTask)
    }

    func dueSoonMessage(of id: TaskItem.ID, in state: PartnershipState) -> String {
        guard let deadline = task(of: id, in: state)?.deadline else {
            return String(localized: .nudgeTaskDeadlineUnknown(title(of: id, in: state)))
        }
        return String(localized: .nudgeTaskDueSoon(title(of: id, in: state), deadline.formatted(Date.FormatStyle.monthDayTime)))
    }

    func name(of role: Role, in state: PartnershipState) -> String {
        state.pairing?.name(of: role) ?? role.label
    }

    func task(of id: TaskItem.ID, in state: PartnershipState) -> TaskItem? {
        state.tasks.first { $0.id == id }
    }
}
