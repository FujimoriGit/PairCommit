//
//  RemoteChangeSignals.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/29
//

import Foundation

/// 相手側の変更を知らせるプッシュの受け口。同期層はこれを購読して状態を取り直す。
@MainActor
final class RemoteChangeSignals {
    private var listeners: [UUID: AsyncStream<Void>.Continuation] = [:]

    func stream() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            listeners[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.listeners[id] = nil }
            }
        }
    }

    func signal() {
        for listener in listeners.values {
            listener.yield()
        }
    }
}
