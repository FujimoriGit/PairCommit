//
//  LinkRefusal.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Foundation

/// 招待リンクを開いても参加しない理由。
enum LinkRefusal: Sendable {
    case alreadyPaired
    case pairingInProgress

    var title: String {
        switch self {
        case .alreadyPaired: String(localized: "すでに相手とつながっています")
        case .pairingInProgress: String(localized: "ペアリングの途中です")
        }
    }

    var message: String {
        switch self {
        case .alreadyPaired: String(localized: "このリンクで参加するには、設定の「ペアリングをやり直す」をしてから、もう一度リンクを開いてください。")
        case .pairingInProgress: String(localized: "いまのペアリングをやめてから、もう一度リンクを開いてください。")
        }
    }
}
