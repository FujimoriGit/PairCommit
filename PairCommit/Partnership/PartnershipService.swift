//
//  PartnershipService.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Foundation
import Observation
import UIKit

/// Spike: MC接続 → (オーナー)URL送信 / (参加者)URL受諾 → ACK返信 を束ねる司令塔。
///
/// 成功の定義は「参加者が受諾を終えて ACK を返し、オーナーがそれを受け取る」まで。
/// オーナーがURLを送っただけでは成功にしない（相手の受諾失敗を成功と誤表示しないため）。
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
    /// 参加者が受諾完了をオーナーへ知らせる合図。
    static let ackMessage = "paircommit://ack"

    /// iOS 16以降 `UIDevice.name` は汎用名（"iPhone"）を返し2台で衝突しうるため、
    /// 招待のタイブレーク（displayName比較）が機能するようランダムなサフィックスを付ける。
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
                // 完了後の切断は正常（MCは一回限り）。リソースだけ片付ける。
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
        // オーナーだけが共有を作ってURLを送る。参加者はURLを待つ。
        guard role == .owner else { return }
        phase = .sharing
        Task {
            do {
                let url = try await PartnershipShare.makeShare()
                try multipeer?.send(url.absoluteString)
                // ここでは完了にしない。参加者のACK受信（handleReceived）で .done になる。
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
                    // すぐ切断するとACKが届く前にセッションが落ちることがあるため、
                    // ここでは止めない。オーナー側の切断（.disconnected）かリセットで片付く。
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
