//
//  Eventually.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/03
//

/// メインアクターに積まれた処理を進めながら、条件が成り立つのを待つ。
@MainActor
func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<1_000 {
        if condition() {
            return true
        }
        await Task.yield()
    }
    return condition()
}
