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

/// 時間をおいて進む処理を待つ。条件が成り立つまで、少しずつ眠りながら確かめる。
@MainActor
func eventually(within timeout: Duration, _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
