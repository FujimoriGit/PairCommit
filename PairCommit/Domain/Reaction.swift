//
//  Reaction.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//


/// プレイヤーがタスクに貼る現在の感情。チャットではなくステート（上書き更新）。
/// ネガティブも安全に出せることが要件（隠れたしんどさは管理者が催促を手加減できなくする）。
enum Reaction: String, Sendable, Codable, CaseIterable {
    case angry
    case uneasy
    case happy

    var emoji: String {
        switch self {
        case .angry:  return "😡"
        case .uneasy: return "😕"
        case .happy:  return "😊"
        }
    }
}
