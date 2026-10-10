//
//  PartnerActionMessage.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import Foundation

extension PartnerAction {
    func message(in state: PartnershipState) -> String {
        let partner = state.pairing?.name(of: recipient.counterpart) ?? recipient.counterpart.label
        return switch self {
        case .visionProposed(let id): String(localized: .partnerActionVisionProposed(partner, statement(of: id, in: state)))
        case .visionApproved(let id): String(localized: .partnerActionVisionApproved(partner, statement(of: id, in: state)))
        case .visionReturned(let id): String(localized: .partnerActionVisionReturned(partner, statement(of: id, in: state)))
        case .visionClosed(let id, .achieved): String(localized: .partnerActionVisionAchieved(partner, statement(of: id, in: state)))
        case .visionClosed(let id, .abandoned): String(localized: .partnerActionVisionAbandoned(partner, statement(of: id, in: state)))
        case .taskAdded(let id): String(localized: .partnerActionTaskAdded(partner, title(of: id, in: state)))
        case .taskProposed(let id): String(localized: .partnerActionTaskProposed(partner, title(of: id, in: state)))
        case .taskAdopted(let id): String(localized: .partnerActionTaskAdopted(partner, title(of: id, in: state)))
        case .taskReported(let id): String(localized: .partnerActionTaskReported(partner, title(of: id, in: state)))
        case .taskApproved(let id): String(localized: .partnerActionTaskApproved(partner, title(of: id, in: state)))
        case .taskReturned(let id): String(localized: .partnerActionTaskReturned(partner, title(of: id, in: state)))
        case .taskCancelled(let id): String(localized: .partnerActionTaskCancelled(partner, title(of: id, in: state)))
        case .reactionChanged(let id, let reaction):
            String(localized: .partnerActionReactionChanged(partner, title(of: id, in: state), reaction.emoji))
        case .progressChanged(let id, let percent):
            String(localized: .partnerActionProgressChanged(partner, title(of: id, in: state), percent))
        }
    }
}

// MARK: - Private

private extension PartnerAction {
    func statement(of id: Vision.ID, in state: PartnershipState) -> String {
        state.visions.first { $0.id == id }?.statement ?? String(localized: .partnerActionUntitledVision)
    }

    func title(of id: TaskItem.ID, in state: PartnershipState) -> String {
        state.tasks.first { $0.id == id }?.title ?? String(localized: .nudgeUntitledTask)
    }
}
