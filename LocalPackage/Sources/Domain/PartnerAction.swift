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
    case visionReturned(Vision.ID, feedback: Note.ID?)
    case visionClosed(Vision.ID, Vision.Outcome)
    case taskAdded(TaskItem.ID)
    case taskProposed(TaskItem.ID)
    case taskAdopted(TaskItem.ID)
    case taskReported(TaskItem.ID)
    case taskApproved(TaskItem.ID, feedback: Note.ID?)
    case taskReturned(TaskItem.ID, feedback: Note.ID?)
    case taskCancelled(TaskItem.ID)
    case reactionChanged(TaskItem.ID, Reaction)
    case progressChanged(TaskItem.ID, Int)
    case noteWritten(Note.ID, on: Note.Subject, author: Role)

    public var recipient: Role {
        switch self {
        case .noteWritten(_, _, let author):
            author.counterpart
        case .visionProposed, .taskProposed, .taskReported, .reactionChanged:
            .manager
        case .visionApproved, .visionReturned, .visionClosed, .taskAdded, .taskAdopted,
             .taskApproved, .taskReturned, .taskCancelled, .progressChanged:
            .player
        }
    }

    public var subject: Note.Subject {
        switch self {
        case .visionProposed(let id), .visionApproved(let id), .visionReturned(let id, _), .visionClosed(let id, _):
            .vision(id)
        case .taskAdded(let id), .taskProposed(let id), .taskAdopted(let id), .taskReported(let id),
             .taskApproved(let id, _), .taskReturned(let id, _), .taskCancelled(let id),
             .reactionChanged(let id, _), .progressChanged(let id, _):
            .task(id)
        case .noteWritten(_, let subject, _):
            subject
        }
    }
}

extension PartnerAction {
    var feedback: Note.ID? {
        switch self {
        case .visionReturned(_, let feedback), .taskApproved(_, let feedback), .taskReturned(_, let feedback): feedback
        default: nil
        }
    }
}
