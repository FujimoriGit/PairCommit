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
    static let ownerHello = "paircommit://hello/owner"
    static let participantHello = "paircommit://hello/participant"

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
                phase = .failed("相手との接続が切れました")
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

    // 相手のデータが、自分側の接続の通知より先に届くことがある。
    func handleConnected() {
        guard phase == .searching else { return }
        phase = .connected
        do {
            try multipeer?.send(isOwner ? Self.ownerHello : Self.participantHello)
        } catch {
            fail(with: error)
        }
    }

    func handleHello(fromOwner peerIsOwner: Bool) {
        handleConnected()
        guard phase == .connected else { return }
        switch (isOwner, peerIsOwner) {
        case (true, true):
            fail(with: "相手も役割を選んでいます。どちらか一方が「相手の招待を受ける」を選んでください。")
        case (false, false):
            fail(with: "2人とも「相手の招待を受ける」を選んでいます。どちらか一方が役割を選んでください。")
        case (true, false):
            startSharing()
        case (false, true):
            break
        }
    }

    func startSharing() {
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
        case Self.ownerHello:
            handleHello(fromOwner: true)
            return
        case Self.participantHello:
            handleHello(fromOwner: false)
            return
        default:
            break
        }
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
        fail(with: error.localizedDescription)
    }

    func fail(with message: String) {
        outcome = nil
        phase = .failed(message)
        tearDown()
    }

    func tearDown() {
        eventTask?.cancel()
        eventTask = nil
        multipeer?.stop()
        multipeer = nil
    }
}
