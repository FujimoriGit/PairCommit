//
//  RoleLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Domain

extension Role {
    var label: String {
        switch self {
        case .manager: "管理者"
        case .player: "プレイヤー"
        }
    }

    var summary: String {
        switch self {
        case .manager: "タスクを作り、完了を承認する。ビジョンを承認し、達成したかを判断する"
        case .player: "ビジョンを起案し、完了を報告する。タスクへの気持ちを表明できる"
        }
    }
}
