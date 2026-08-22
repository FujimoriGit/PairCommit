//
//  FailureMessage.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Application
import Domain

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
        case .roleForbidden(let required): "\(required.label)だけができる操作です"
        case .visionNotFound: "ビジョンが見つかりません"
        case .taskNotFound: "タスクが見つかりません"
        case .invalidVisionTransition: "いまのビジョンの状態ではできない操作です"
        case .invalidTaskTransition: "いまのタスクの状態ではできない操作です"
        case .activeVisionAlreadyExists: "進行中のビジョンがすでにあります"
        case .noActiveVision: "進行中のビジョンがありません"
        case .alreadyPaired: "すでにペアが成立しています"
        }
    }
}

extension SyncFailure {
    var message: String {
        switch self {
        case .unavailable: "相手と同期できませんでした"
        }
    }
}
