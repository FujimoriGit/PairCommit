//
//  Reaction.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

public enum Reaction: String, Sendable, Codable, CaseIterable {
    case angry
    case uneasy
    case happy

    public var emoji: String {
        switch self {
        case .angry:  return "😡"
        case .uneasy: return "😕"
        case .happy:  return "😊"
        }
    }
}
