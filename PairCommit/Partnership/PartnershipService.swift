//
//  PairingService.swift
//  PairCommit
//  
//  Created by Daiki Fujimori on 2026/06/20
//  


import Foundation
import Observation

/// Spike: MC接続 → (オーナー)URL送信 / (参加者)URL受諾 を束ねる司令塔。
@MainActor
@Observable
final class PairingService {
    enum Role { case owner, participant }

    enum Phase: Equatable {
        case idle
        case searching
        case connected
        case sharing
        case done
        case failed(String)

        var label: String {
            switch self {
            case .idle:        return "待機中"
            case .searching:   return "相手を探しています…"
            case .connected:   return "接続しました"
            case .sharing:     return "共有を処理中…"
            case .done:        return "ペアリング成功 🎉"
            case .failed(let m): return "失敗: \(m)"
            }
        }
    }

    private(set) var phase: Phase = .idle

    private let mc = MultipeerSession()
    private var role: Role = .owner

    func start(as role: Role) {
        self.role = role
        phase = .searching

        mc.onConnected = { [weak self] in
            Task { @MainActor in self?.handleConnected() }
        }
        mc.onReceiveText = { [weak self] text in
            Task { @MainActor in self?.handleReceived(text) }
        }
        mc.onError = { [weak self] message in
            Task { @MainActor in self?.phase = .failed(message) }
        }
        mc.start()
    }

    func reset() {
        mc.stop()
        phase = .idle
    }
}

// MARK: - Private

private extension PairingService {
    func handleConnected() {
        phase = .connected
        // オーナーだけが共有を作って URL を送る。参加者は URL を待つ。
        guard role == .owner else { return }
        phase = .sharing
        Task {
            do {
                let url = try await PairingShare.makeShare()
                mc.send(url.absoluteString)
                phase = .done
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func handleReceived(_ text: String) {
        guard role == .participant, let url = URL(string: text) else { return }
        phase = .sharing
        Task {
            do {
                try await PairingShare.acceptShare(from: url)
                phase = .done
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
