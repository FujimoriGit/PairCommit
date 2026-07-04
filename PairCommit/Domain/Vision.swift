//
//  Vision.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

/// プレイヤーの目標。タスクの上位概念。
/// 発生源はプレイヤー、執行権限（承認・達成判断）は管理者。
/// 中心の不変条件: `active` はペア内で高々1個（`PartnershipState` が守る）。
struct Vision: Identifiable, Sendable, Codable, Equatable {
    enum Status: String, Sendable, Codable {
        /// 起案中（プレイヤーの手元）。
        case draft
        /// 管理者の承認待ち。却下されると draft に戻る。
        case proposed
        /// 確定。高々1個。
        case active
        /// 達成（履歴）。管理者の質的判断で決まる。
        case achieved
        /// 中止（履歴）。
        case abandoned
    }

    /// active な Vision を閉じるときの結末。
    enum Outcome: String, Sendable, Codable {
        case achieved
        case abandoned

        var status: Status {
            switch self {
            case .achieved:  return .achieved
            case .abandoned: return .abandoned
            }
        }
    }

    let id: UUID
    /// ビジョンそのもの（一文）。例「半年で10kg痩せて健康診断オールA」。
    var statement: String
    /// 管理者の達成判断のよりどころ。憲法の改正条件にあたる。
    var doneCriteria: String
    /// 催促のペース配分に直結。残り日数で催促の強弱を決める。
    var deadline: Date?
    /// 管理者が催促トーンを測る材料 + プレイヤーがしんどい時に立ち返る錨。
    var why: String?
    var status: Status
    let createdAt: Date
}
