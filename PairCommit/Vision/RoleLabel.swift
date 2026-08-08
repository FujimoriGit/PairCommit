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
}
