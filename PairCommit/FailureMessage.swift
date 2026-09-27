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
        case .roleForbidden(let required): String(localized: "\(required.label)だけができる操作です")
        case .visionNotFound: String(localized: "ビジョンが見つかりません")
        case .taskNotFound: String(localized: "タスクが見つかりません")
        case .invalidVisionTransition: String(localized: "いまのビジョンの状態ではできない操作です")
        case .invalidTaskTransition: String(localized: "いまのタスクの状態ではできない操作です")
        case .activeVisionAlreadyExists: String(localized: "進行中のビジョンがすでにあります")
        case .noActiveVision: String(localized: "進行中のビジョンがありません")
        case .alreadyPaired: String(localized: "すでにペアが成立しています")
        case .blankText: String(localized: "空白だけの内容は登録できません")
        }
    }
}

extension FailureReason {
    var message: String {
        switch self {
        case .signedOutOfICloud: String(localized: "iCloud にサインインしていません。設定アプリでサインインしてから、もう一度お試しください")
        case .iCloudAccountUnverified: String(localized: "iCloud アカウントの確認が済んでいません。設定アプリで確かめてから、もう一度お試しください")
        case .iCloudFull: String(localized: "iCloud のストレージがいっぱいです。空きを作ってから、もう一度お試しください")
        case .iCloudBusy: String(localized: "iCloud が混み合っています。しばらくしてから、もう一度お試しください")
        case .offline: String(localized: "インターネットにつながっていません。通信できる場所で、もう一度お試しください")
        case .nearbyUnavailable:
            String(localized: "近くの端末を探せませんでした。Wi-Fi と Bluetooth がオンになっているか、設定アプリで「ローカルネットワーク」が許可されているかを確かめてください")
        case .disconnected: String(localized: "相手との接続が切れました。2台を近くに置いたまま、もう一度お試しください")
        case .partnerFailed: String(localized: "相手の端末でペアリングできませんでした。相手の画面の案内を確かめてから、もう一度お試しください")
        case .sameRole(let role): String(localized: "2台とも「\(role.label)」を選んでいます。片方の端末では「\(role.counterpart.label)」を選んでください")
        case .bothAccepting: String(localized: "2台とも「相手の招待を受ける」を押しています。片方の端末では役割を選んでください")
        case .invitationWithdrawn: String(localized: "相手が招待をやめました。もう一度、招待リンクを送ってもらってください")
        case .unexpected: String(localized: "うまくいきませんでした。もう一度お試しください")
        }
    }
}

extension SyncFailure {
    var message: String {
        switch self {
        case .unavailable: String(localized: "相手と同期できませんでした")
        case .outdated: String(localized: "相手の操作と重なりました。もう一度お試しください")
        }
    }
}
