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
        case .proposed: String(localized: "採用待ち")
        case .todo: String(localized: "未完了")
        case .reported: String(localized: "承認待ち")
        case .approved: String(localized: "完了")
        case .cancelled: String(localized: "取り消し")
        }
    }

    var tint: Color {
        switch self {
        case .proposed, .reported: .orange
        case .approved: .green
        case .todo, .cancelled: .secondary
        }
    }
}
