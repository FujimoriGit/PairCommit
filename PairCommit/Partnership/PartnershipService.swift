//
//  PartnershipService.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class PartnershipService {
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
            case .failed(let message): return "失敗: \(message)"
            }
        }
    }

    private(set) var phase: Phase = .idle

    private var multipeer: MultipeerSession?
    private var eventTask: Task<Void, Never>?
    private var role: Role = .owner

    func start(as role: Role) {
        guard phase == .idle else { return }
        self.role = role
        phase = .searching

        let session = MultipeerSession(displayName: Self.makeDisplayName())
        multipeer = session
        eventTask = Task { [weak self] in
            for await event in session.events {
                self?.handle(event)
            }
        }
        session.start()
    }

    func reset() {
        tearDown()
        phase = .idle
    }
}

// MARK: - Private

private extension PartnershipService {
    static let ackMessage = "paircommit://ack"

    // iOS 16 以降 UIDevice.name は汎用名を返し、2台とも "iPhone" で衝突しうる。
    static func makeDisplayName() -> String {
        "\(UIDevice.current.name.prefix(24))#\(UUID().uuidString.prefix(4))"
    }

    func handle(_ event: MultipeerSession.Event) {
        switch event {
        case .connected:
            handleConnected()
        case .received(let text):
            handleReceived(text)
        case .disconnected:
            switch phase {
            case .connected, .sharing:
                phase = .failed("接続が切れた")
                tearDown()
            case .done:
                // 完了後の切断は正常。
                tearDown()
            case .idle, .searching, .failed:
                break
            }
        case .failed(let message):
            phase = .failed(message)
            tearDown()
        }
    }

    func handleConnected() {
        phase = .connected
        guard role == .owner else { return }
        phase = .sharing
        Task {
            do {
                let url = try await PartnershipShare.makeShare()
                try multipeer?.send(url.absoluteString)
                // 完了にするのは ACK を受け取った時点。
            } catch {
                phase = .failed(error.localizedDescription)
                tearDown()
            }
        }
    }

    func handleReceived(_ text: String) {
        switch role {
        case .owner:
            guard phase == .sharing, text == Self.ackMessage else { return }
            phase = .done
            tearDown()
        case .participant:
            guard phase == .connected, let url = URL(string: text) else { return }
            phase = .sharing
            Task {
                do {
                    try await PartnershipShare.acceptShare(from: url)
                    try multipeer?.send(Self.ackMessage)
                    // すぐ切断すると ACK が届く前にセッションが落ちることがある。
                    phase = .done
                } catch {
                    phase = .failed(error.localizedDescription)
                    tearDown()
                }
            }
        }
    }

    func tearDown() {
        eventTask?.cancel()
        eventTask = nil
        multipeer?.stop()
        multipeer = nil
    }
}
