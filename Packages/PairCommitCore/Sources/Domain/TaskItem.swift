//
//  TaskItem.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

/// 管理者が所有するタスク。必ず1つの Vision に紐づく（孤立タスクは存在しない）。
/// 型名は Swift Concurrency の `Task` との衝突を避けて `TaskItem`（設計上の呼称は「タスク」のまま）。
public struct TaskItem: Identifiable, Sendable, Codable, Equatable {
    public enum Status: String, Sendable, Codable {
        /// プレイヤー起案・管理者の採用待ち。採用で todo、却下で cancelled。
        case proposed
        /// 着手待ち（管理者が生成したタスクの初期状態）。
        case todo
        /// プレイヤーが完了報告。承認待ちで止まる。差し戻しで todo に戻る。
        case reported
        /// 管理者が承認（完了）。終端。
        case approved
        /// 却下、または Vision クローズ時の巻き込み。終端。
        case cancelled

        /// まだ完了/終端に達していないか（Vision クローズ時に巻き込まれる対象）。
        public var isOpen: Bool {
            switch self {
            case .proposed, .todo, .reported: return true
            case .approved, .cancelled:       return false
            }
        }
    }

    public let id: UUID
    public let visionID: Vision.ID
    public var title: String
    public var status: Status
    /// 起案者。プレイヤーも起案できる（所有・承認は管理者のまま）。
    public let createdBy: Role
    /// プレイヤーの現在の感情（ステート・上書き）。ヒートマップの1マス。
    public var reaction: Reaction?
    public var deadline: Date?
    public let createdAt: Date

    /// 同期層が受信データから再構築するための入口。アプリ内の新規作成は
    /// `PartnershipState.createTask` を使う（状態遷移は集約ルートが守る）。
    public init(
        id: UUID,
        visionID: Vision.ID,
        title: String,
        status: Status,
        createdBy: Role,
        reaction: Reaction?,
        deadline: Date?,
        createdAt: Date
    ) {
        self.id = id
        self.visionID = visionID
        self.title = title
        self.status = status
        self.createdBy = createdBy
        self.reaction = reaction
        self.deadline = deadline
        self.createdAt = createdAt
    }
}
