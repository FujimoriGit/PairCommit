//
//  MultipeerPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import CloudKit
import Domain
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class MultipeerPairing {
    struct Outcome: Sendable {
        let rootRecordID: CKRecord.ID
        let isOwner: Bool
    }

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
    private(set) var outcome: Outcome?

    private var multipeer: MultipeerSession?
    private var eventTask: Task<Void, Never>?
    private var side: PairingSide = .participant

    func start(as side: PairingSide) {
        guard phase == .idle else { return }
        self.side = side
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
        outcome = nil
        phase = .idle
    }
}

// MARK: - Private

private extension MultipeerPairing {
    static let ackMessage = "paircommit://ack"

    // iOS 16 以降 UIDevice.name は汎用名を返し、2台とも "iPhone" で衝突しうる。
    static func makeDisplayName() -> String {
        "\(UIDevice.current.name.prefix(24))#\(UUID().uuidString.prefix(4))"
    }

    var isOwner: Bool {
        if case .owner = side { return true }
        return false
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
        guard case .owner(let role) = side else { return }
        phase = .sharing
        Task {
            do {
                // 相手はロールを受け取るのではなく、共有された状態から読む。
                let paired = try PartnershipState().establishingPairing(ownerRole: role)
                let share = try await PartnershipShare.makeShare(initialState: paired)
                outcome = Outcome(rootRecordID: share.rootRecordID, isOwner: true)
                try multipeer?.send(share.url.absoluteString)
                // 完了にするのは ACK を受け取った時点。
            } catch {
                fail(with: error)
            }
        }
    }

    func handleReceived(_ text: String) {
        if isOwner {
            guard phase == .sharing, text == Self.ackMessage else { return }
            phase = .done
            tearDown()
        } else {
            guard phase == .connected, let url = URL(string: text) else { return }
            phase = .sharing
            Task {
                do {
                    let rootRecordID = try await PartnershipShare.acceptShare(from: url)
                    outcome = Outcome(rootRecordID: rootRecordID, isOwner: false)
                    try multipeer?.send(Self.ackMessage)
                    // すぐ切断すると ACK が届く前にセッションが落ちることがある。
                    phase = .done
                } catch {
                    fail(with: error)
                }
            }
        }
    }

    func fail(with error: any Error) {
        outcome = nil
        phase = .failed(error.localizedDescription)
        tearDown()
    }

    func tearDown() {
        eventTask?.cancel()
        eventTask = nil
        multipeer?.stop()
        multipeer = nil
    }
}
