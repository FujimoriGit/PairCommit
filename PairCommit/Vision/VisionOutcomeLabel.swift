//
//  VisionOutcomeLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import SwiftUI

extension Vision.Outcome {
    var label: String {
        switch self {
        case .achieved: String(localized: "達成した", comment: "ビジョンを閉じるときに選ぶ結果")
        case .abandoned: String(localized: "取りやめる", comment: "ビジョンを閉じるときに選ぶ結果")
        }
    }

    var result: String {
        switch self {
        case .achieved: String(localized: "達成", comment: "閉じたビジョンの結果")
        case .abandoned: String(localized: "取りやめ", comment: "閉じたビジョンの結果")
        }
    }

    var confirmation: String {
        switch self {
        case .achieved: String(localized: "達成にする", comment: "ビジョンを閉じる確認のボタン")
        case .abandoned: String(localized: "取りやめにする", comment: "ビジョンを閉じる確認のボタン")
        }
    }

    var tint: Color {
        switch self {
        case .achieved: .green
        case .abandoned: .secondary
        }
    }
}
