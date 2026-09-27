//
//  RoleLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain
import Foundation

extension Role {
    var label: String {
        switch self {
        case .manager: String(localized: "見届ける人")
        case .player: String(localized: "挑む人")
        }
    }

    var summary: String {
        switch self {
        case .manager: String(localized: "タスクを作り、完了を承認する。ビジョンを承認し、達成したかを判断する")
        case .player: String(localized: "ビジョンを起案し、完了を報告する。タスクへの気持ちを表明できる")
        }
    }
}
