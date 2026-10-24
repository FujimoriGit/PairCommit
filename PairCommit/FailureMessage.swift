//
//  FailureMessage.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Application
import Domain
import Foundation

protocol PresentableError: Error {
    var message: String { get }
}

extension PartnershipFailure where Rejection: PresentableError {
    var message: String {
        switch self {
        case .rejected(let error): error.message
        case .notSynchronized(let failure): failure.message
        }
    }
}

extension NamingError: PresentableError {
    var message: String {
        switch self {
        case .notPaired: String(localized: .errorNotPaired)
        case .blankName: String(localized: .errorBlankText)
        }
    }
}

extension VisionDraftingError: PresentableError {
    var message: String {
        switch self {
        case .notPlayer: .onlyPlayer
        case .blankStatement, .blankDoneCriteria: String(localized: .errorBlankText)
        case .pastDeadline: String(localized: .errorPastDeadline)
        }
    }
}

extension VisionRevisionError: PresentableError {
    var message: String {
        switch self {
        case .notPlayer: .onlyPlayer
        case .visionNotFound: String(localized: .errorVisionNotFound)
        case .notDraft: String(localized: .errorInvalidVisionTransition)
        case .blankStatement, .blankDoneCriteria: String(localized: .errorBlankText)
        case .pastDeadline: String(localized: .errorPastDeadline)
        }
    }
}

extension VisionProposalError: PresentableError {
    var message: String {
        switch self {
        case .notPlayer: .onlyPlayer
        case .visionNotFound: String(localized: .errorVisionNotFound)
        case .notDraft: String(localized: .errorInvalidVisionTransition)
        case .pastDeadline: String(localized: .errorPastDeadline)
        }
    }
}

extension VisionDiscardingError: PresentableError {
    var message: String {
        switch self {
        case .notPlayer: .onlyPlayer
        case .visionNotFound: String(localized: .errorVisionNotFound)
        case .notDraft: String(localized: .errorInvalidVisionTransition)
        }
    }
}

extension VisionApprovalError: PresentableError {
    var message: String {
        switch self {
        case .notManager: .onlyManager
        case .visionNotFound: String(localized: .errorVisionNotFound)
        case .notProposed: String(localized: .errorInvalidVisionTransition)
        case .activeVisionExists: String(localized: .errorActiveVisionAlreadyExists)
        case .pastDeadline: String(localized: .errorPastDeadline)
        }
    }
}

extension VisionRejectionError: PresentableError {
    var message: String {
        switch self {
        case .notManager: .onlyManager
        case .visionNotFound: String(localized: .errorVisionNotFound)
        case .notProposed: String(localized: .errorInvalidVisionTransition)
        }
    }
}

extension VisionClosingError: PresentableError {
    var message: String {
        switch self {
        case .notManager: .onlyManager
        case .visionNotFound: String(localized: .errorVisionNotFound)
        case .notActive: String(localized: .errorInvalidVisionTransition)
        }
    }
}

extension TaskCreationError: PresentableError {
    var message: String {
        switch self {
        case .noActiveVision: String(localized: .errorNoActiveVision)
        case .blankTitle: String(localized: .errorBlankText)
        case .pastDeadline: String(localized: .errorPastDeadline)
        }
    }
}

extension TaskAdoptionError: PresentableError {
    var message: String {
        switch self {
        case .notManager: .onlyManager
        case .taskNotFound: String(localized: .errorTaskNotFound)
        case .notProposed: String(localized: .errorInvalidTaskTransition)
        case .pastDeadline: String(localized: .errorPastDeadline)
        }
    }
}

extension TaskReportError: PresentableError {
    var message: String {
        switch self {
        case .notPlayer: .onlyPlayer
        case .taskNotFound: String(localized: .errorTaskNotFound)
        case .notTodo: String(localized: .errorInvalidTaskTransition)
        }
    }
}

extension TaskApprovalError: PresentableError {
    var message: String {
        switch self {
        case .notManager: .onlyManager
        case .taskNotFound: String(localized: .errorTaskNotFound)
        case .notReported: String(localized: .errorInvalidTaskTransition)
        }
    }
}

extension TaskReturnError: PresentableError {
    var message: String {
        switch self {
        case .notManager: .onlyManager
        case .taskNotFound: String(localized: .errorTaskNotFound)
        case .notReported: String(localized: .errorInvalidTaskTransition)
        case .blankFeedback: String(localized: .errorBlankText)
        }
    }
}

extension TaskCancellationError: PresentableError {
    var message: String {
        switch self {
        case .notManager: .onlyManager
        case .taskNotFound: String(localized: .errorTaskNotFound)
        case .alreadyClosed: String(localized: .errorInvalidTaskTransition)
        }
    }
}

extension TaskRestorationError: PresentableError {
    var message: String {
        switch self {
        case .notManager: .onlyManager
        case .taskNotFound: String(localized: .errorTaskNotFound)
        case .notRestorable: String(localized: .errorInvalidTaskTransition)
        }
    }
}

extension ReactionError: PresentableError {
    var message: String {
        switch self {
        case .notPlayer: .onlyPlayer
        case .taskNotFound: String(localized: .errorTaskNotFound)
        }
    }
}

extension ProgressError: PresentableError {
    var message: String {
        switch self {
        case .notManager: .onlyManager
        case .taskNotFound: String(localized: .errorTaskNotFound)
        case .notInProgress: String(localized: .errorInvalidTaskTransition)
        case .outOfRange: String(localized: .errorProgressOutOfRange)
        }
    }
}

extension NoteWritingError: PresentableError {
    var message: String {
        switch self {
        case .blankBody: String(localized: .errorBlankText)
        case .subjectNotFound: String(localized: .errorNoteSubjectNotFound)
        case .subjectClosed: String(localized: .errorNoteSubjectClosed)
        }
    }
}

extension PairingFailure {
    var message: String {
        switch self {
        case .signedOut: String(localized: .errorSignedOut)
        case .accountUnverified: String(localized: .errorAccountUnverified)
        case .storageFull: String(localized: .errorStorageFull)
        case .serverBusy: String(localized: .errorServerBusy)
        case .offline: String(localized: .errorOffline)
        case .nearbyUnavailable:
            String(localized: .errorNearbyUnavailable)
        case .localNetworkDenied: String(localized: .errorLocalNetworkDenied)
        case .disconnected: String(localized: .errorDisconnected)
        case .invitationWithdrawn: String(localized: .errorInvitationWithdrawn)
        case .unexpected: String(localized: .errorUnexpected)
        }
    }
}

extension NearbyPairing.Failure {
    var message: String {
        switch self {
        case .partnerFailed: String(localized: .errorPartnerFailed)
        case .sameRole(let role): String(localized: .errorSameRole(role.label, role.counterpart.label))
        case .external(let failure): failure.message
        }
    }
}

extension PartnershipSession.Interruption {
    var message: String {
        switch self {
        case .partnershipEnded: String(localized: .rootPartnershipEnded)
        case .pairingResultMissing: String(localized: .rootPairingResultMissing)
        case .partnerSetupMissing: String(localized: .rootPartnerSetupMissing)
        }
    }
}

extension SyncFailure {
    var message: String {
        switch self {
        case .unavailable: String(localized: .errorSyncUnavailable)
        case .outdated: String(localized: .errorSyncOutdated)
        }
    }
}

// MARK: - Private

private extension String {
    static var onlyPlayer: Self { .init(localized: .errorRoleForbidden(Role.player.label)) }
    static var onlyManager: Self { .init(localized: .errorRoleForbidden(Role.manager.label)) }
}
