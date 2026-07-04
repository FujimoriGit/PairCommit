//
//  DomainError.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

/// ドメイン操作の失敗。ロール権限・状態遷移・不変条件の違反を型で表す。
enum DomainError: Error, Equatable {
    /// そのロールには許されていない操作（非対称性のガード）。
    case roleForbidden(required: Role)
    case visionNotFound(Vision.ID)
    case taskNotFound(TaskItem.ID)
    /// 現在の状態からは許されない遷移。
    case invalidVisionTransition(from: Vision.Status)
    case invalidTaskTransition(from: TaskItem.Status)
    /// active な Vision は高々1個（中心の不変条件）。
    case activeVisionAlreadyExists
    /// タスクは active な Vision の下にしか作れない。
    case noActiveVision
    case alreadyPaired
}
