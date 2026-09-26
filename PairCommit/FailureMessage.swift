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
        case .blankText: "空白だけの内容は登録できません"
        }
    }
}

extension FailureReason {
    var message: String {
        switch self {
        case .signedOutOfICloud: "iCloud にサインインしていません。設定アプリでサインインしてから、もう一度お試しください"
        case .iCloudAccountUnverified: "iCloud アカウントの確認が済んでいません。設定アプリで確かめてから、もう一度お試しください"
        case .iCloudFull: "iCloud のストレージがいっぱいです。空きを作ってから、もう一度お試しください"
        case .iCloudBusy: "iCloud が混み合っています。しばらくしてから、もう一度お試しください"
        case .offline: "インターネットにつながっていません。通信できる場所で、もう一度お試しください"
        case .nearbyUnavailable:
            "近くの端末を探せませんでした。Wi-Fi と Bluetooth がオンになっているか、設定アプリで「ローカルネットワーク」が許可されているかを確かめてください"
        case .disconnected: "相手との接続が切れました。2台を近くに置いたまま、もう一度お試しください"
        case .partnerFailed: "相手の端末でペアリングできませんでした。相手の画面の案内を確かめてから、もう一度お試しください"
        case .unexpected: "うまくいきませんでした。もう一度お試しください"
        }
    }
}

extension SyncFailure {
    var message: String {
        switch self {
        case .unavailable: "相手と同期できませんでした"
        case .outdated: "相手の操作と重なりました。もう一度お試しください"
        }
    }
}
