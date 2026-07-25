//
//  DomainError.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

public enum DomainError: Error, Equatable {
    case roleForbidden(required: Role)
    case visionNotFound(Vision.ID)
    case taskNotFound(TaskItem.ID)
    case invalidVisionTransition(from: Vision.Status)
    case invalidTaskTransition(from: TaskItem.Status)
    case activeVisionAlreadyExists
    case noActiveVision
    case alreadyPaired
}
