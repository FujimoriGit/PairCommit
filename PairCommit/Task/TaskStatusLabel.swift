//
//  TaskStatusLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain
import SwiftUI

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

    var tint: Color {
        switch self {
        case .proposed, .reported: Color(.deepOrange)
        case .approved: Color(.deepGreen)
        case .todo, .cancelled: .secondary
        }
    }
}
