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
import OSLog
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
        case failed(FailureReason)

        var label: String {
            switch self {
            case .idle:        return "待機中"
            case .searching:   return "相手を探しています…"
            case .connected:   return "相手が見つかりました"
            case .sharing:     return "ペアを登録しています…"
            case .done:        return "ペアリングできました 🎉"
            case .failed:      return "ペアリングできませんでした"
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
    static let failureMessage = "paircommit://failed"
    static let ownerMessage = "paircommit://owner"
    static let participantMessage = "paircommit://participant"

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
                Logger.pairing.error("disconnected: \(String(describing: self.phase), privacy: .public)")
                phase = .failed(.disconnected)
                tearDown()
            case .done, .failed:
                // 完了後や、失敗を知らせたあとの切断は正常。
                tearDown()
            case .idle, .searching:
                break
            }
        case .failed:
            phase = .failed(.nearbyUnavailable)
            tearDown()
        }
    }

    func handleConnected() {
        phase = .connected
        do {
            try multipeer?.send(isOwner ? Self.ownerMessage : Self.participantMessage)
        } catch {
            fail(with: error)
        }
    }

    func handlePartnerSide(isOwner partnerIsOwner: Bool) {
        guard phase == .connected else { return }
        guard partnerIsOwner != isOwner else {
            // 相手も同じ判定で止まるので知らせない。すぐ切ると、こちらの送信が届く前にセッションが落ちることがある。
            phase = .failed(isOwner ? .bothChoseRoles : .bothAccepting)
            return
        }
        guard case .owner(let role) = side else { return }
        phase = .sharing
        Task {
            do {
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
        switch text {
        case Self.failureMessage:
            guard phase == .connected || phase == .sharing else { return }
            outcome = nil
            phase = .failed(.partnerFailed)
            tearDown()
        case Self.ownerMessage, Self.participantMessage:
            handlePartnerSide(isOwner: text == Self.ownerMessage)
        case Self.ackMessage:
            guard isOwner, phase == .sharing else { return }
            phase = .done
            tearDown()
        default:
            guard !isOwner, phase == .connected, let url = URL(string: text) else { return }
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
        Logger.pairing.error("\(self.isOwner ? "owner" : "participant", privacy: .public): \(error, privacy: .public)")
        outcome = nil
        phase = .failed(FailureReason(error))
        // 知らせないと、相手には接続が切れたとしか見えない。すぐ切ると届く前にセッションが落ちるので、
        // 切るのは相手が受け取って切断したとき。
        do {
            try multipeer?.send(Self.failureMessage)
        } catch {
            tearDown()
        }
    }

    func tearDown() {
        eventTask?.cancel()
        eventTask = nil
        multipeer?.stop()
        multipeer = nil
    }
}
