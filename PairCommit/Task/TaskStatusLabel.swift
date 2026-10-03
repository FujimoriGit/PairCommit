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
        case .proposed: String(localized: "採用待ち", comment: "タスクの状態。起案されて、見届ける人の採用を待っている")
        case .todo: String(localized: "未完了", comment: "タスクの状態。採用されて、まだ完了を報告していない")
        case .reported: String(localized: "承認待ち", comment: "タスクやビジョンの状態。見届ける人の承認を待っている")
        case .approved: String(localized: "完了", comment: "タスクの状態。完了が承認された")
        case .cancelled: String(localized: "取り消し", comment: "タスクの状態。取り消された")
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
