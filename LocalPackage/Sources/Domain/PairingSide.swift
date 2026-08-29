//
//  PairingSide.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

/// ペアリングを始める側と、招待を受ける側。ロールを選べるのは始める側だけ。
public enum PairingSide: Equatable, Sendable {
    case owner(Role)
    case participant
}
