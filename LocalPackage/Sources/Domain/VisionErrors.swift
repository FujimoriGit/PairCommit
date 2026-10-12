//
//  VisionErrors.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Foundation

public enum VisionDraftingError: Error, Equatable {
    case notPlayer
    case blankStatement
    case blankDoneCriteria
    case pastDeadline
}

public enum VisionRevisionError: Error, Equatable {
    case notPlayer
    case visionNotFound
    case notDraft
    case blankStatement
    case blankDoneCriteria
    case pastDeadline
}

public enum VisionProposalError: Error, Equatable {
    case notPlayer
    case visionNotFound
    case notDraft
    case pastDeadline
}

public enum VisionDiscardingError: Error, Equatable {
    case notPlayer
    case visionNotFound
    case notDraft
}

public enum VisionApprovalError: Error, Equatable {
    case notManager
    case visionNotFound
    case notProposed
    case activeVisionExists
    case pastDeadline
}

public enum VisionRejectionError: Error, Equatable {
    case notManager
    case visionNotFound
    case notProposed
}

public enum VisionClosingError: Error, Equatable {
    case notManager
    case visionNotFound
    case notActive
}
