//
//  TaskStatusLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain

extension TaskItem.Status {
    var label: String {
        switch self {
        case .proposed: "採用待ち"
        case .todo: "未完了"
        case .reported: "承認待ち"
        case .approved: "完了"
        case .cancelled: "取り消し"
        }
    }
}
