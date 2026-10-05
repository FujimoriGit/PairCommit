//
//  FailureMessage.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Application
import Domain
import Foundation

extension PartnershipFailure {
    var message: String {
        switch self {
        case .rejected(let error): error.message
        case .notSynchronized(let failure): failure.message
        }
    }
}

extension DomainError {
    var message: String {
        switch self {
        case .roleForbidden(let required): String(localized: .errorRoleForbidden(required.label))
        case .visionNotFound: String(localized: .errorVisionNotFound)
        case .taskNotFound: String(localized: .errorTaskNotFound)
        case .invalidVisionTransition: String(localized: .errorInvalidVisionTransition)
        case .invalidTaskTransition: String(localized: .errorInvalidTaskTransition)
        case .activeVisionAlreadyExists: String(localized: .errorActiveVisionAlreadyExists)
        case .noActiveVision: String(localized: .errorNoActiveVision)
        case .alreadyPaired: String(localized: .errorAlreadyPaired)
        case .blankText: String(localized: .errorBlankText)
        case .pastDeadline: String(localized: .errorPastDeadline)
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
        case .bothAccepting: String(localized: .errorBothAccepting)
        case .external(let failure): failure.message
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
