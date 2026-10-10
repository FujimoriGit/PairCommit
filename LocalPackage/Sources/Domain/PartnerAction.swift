//
//  PartnerAction.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Foundation

/// 相手が自分に向けて行った操作。
public enum PartnerAction: Hashable, Sendable {
    case visionProposed(Vision.ID)
    case visionApproved(Vision.ID)
    case visionReturned(Vision.ID)
    case visionClosed(Vision.ID, Vision.Outcome)
    case taskAdded(TaskItem.ID)
    case taskProposed(TaskItem.ID)
    case taskAdopted(TaskItem.ID)
    case taskReported(TaskItem.ID)
    case taskApproved(TaskItem.ID)
    case taskReturned(TaskItem.ID)
    case taskCancelled(TaskItem.ID)
    case reactionChanged(TaskItem.ID, Reaction)
    case progressChanged(TaskItem.ID, Int)
    case noteWritten(Note.ID, author: Role)

    public var recipient: Role {
        switch self {
        case .noteWritten(_, let author):
            author.counterpart
        case .visionProposed, .taskProposed, .taskReported, .reactionChanged:
            .manager
        case .visionApproved, .visionReturned, .visionClosed, .taskAdded, .taskAdopted,
             .taskApproved, .taskReturned, .taskCancelled, .progressChanged:
            .player
        }
    }
}
