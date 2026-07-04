//
//  Role.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//


/// ペアにおける固定ロール。スワップなし（入れ替えはリセットして再ペアリング）。
/// 管理者が絶対なのは手段（タスク・催促・承認）に対してであり、目的（ビジョン）に対してではない。
enum Role: String, Sendable, Codable, CaseIterable {
    /// タスクの生成・完了承認・催促・ビジョン承認・達成判断を握る。
    case manager
    /// ビジョンの起案・進捗報告・感情表明。唯一の主体性が「感情を表明すること」。
    case player
}
