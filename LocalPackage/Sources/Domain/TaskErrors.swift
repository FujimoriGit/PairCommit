//
//  TaskErrors.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Foundation

public enum TaskCreationError: Error, Equatable {
    case noActiveVision
    case blankTitle
    case pastDeadline
}

public enum TaskAdoptionError: Error, Equatable {
    case notManager
    case taskNotFound
    case notProposed
    case pastDeadline
}

public enum TaskReportError: Error, Equatable {
    case notPlayer
    case taskNotFound
    case notTodo
}

public enum TaskApprovalError: Error, Equatable {
    case notManager
    case taskNotFound
    case notReported
}

public enum TaskReturnError: Error, Equatable {
    case notManager
    case taskNotFound
    case notReported
    case blankFeedback
}

public enum TaskCancellationError: Error, Equatable {
    case notManager
    case taskNotFound
    case alreadyClosed
}

public enum TaskRestorationError: Error, Equatable {
    case notManager
    case taskNotFound
    case notRestorable
}

public enum ReactionError: Error, Equatable {
    case notPlayer
    case taskNotFound
}

public enum ProgressError: Error, Equatable {
    case notManager
    case taskNotFound
    case notInProgress
    case outOfRange
}
