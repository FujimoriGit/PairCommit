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
        case handedOver
        case done
        case failed(FailureReason)

        var label: String {
            switch self {
            case .idle:        return "待機中"
            case .searching:   return "相手を探しています…"
            case .connected:   return "相手が見つかりました"
            case .sharing, .handedOver: return "ペアを登録しています…"
            case .done:        return "ペアリングできました 🎉"
            case .failed:      return "ペアリングできませんでした"
            }
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var outcome: Outcome?

    private var multipeer: MultipeerSession?
    private var eventTask: Task<Void, Never>?
    private var choice: PairingChoice = .invitation

    func start(with choice: PairingChoice) {
        guard phase == .idle else { return }
        self.choice = choice
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
    static let choicePrefix = "paircommit://choice/"
    static let invitationName = "invitation"
    static let handOverPrefix = "paircommit://hand-over/"

    static func message(for choice: PairingChoice) -> String {
        switch choice {
        case .role(let role): choicePrefix + role.rawValue
        case .invitation: choicePrefix + invitationName
        }
    }

    static func choice(from message: String) -> PairingChoice? {
        guard message.hasPrefix(choicePrefix) else { return nil }
        let name = String(message.dropFirst(choicePrefix.count))
        if name == invitationName { return .invitation }
        return Role(rawValue: name).map { .role($0) }
    }

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
            case .connected, .sharing, .handedOver:
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
        if phase == .searching {
            phase = .connected
        }
        do {
            try multipeer?.send(Self.message(for: choice))
        } catch {
            fail(with: error)
        }
    }

    func handlePartnerChoice(_ partner: PairingChoice) {
        // MC は、接続の知らせと受信のどちらが先に届くかを文書で約束していない。
        guard phase == .searching || phase == .connected else { return }
        phase = .connected
        // 止めるときは、相手も同じ判定で止まるので知らせない。すぐ切ると、こちらの送信が届く前にセッションが落ちることがある。
        switch choice.plan(with: partner) {
        case .makeShare(let ownerRole):
            makeShare(ownerRole: ownerRole, handsOverOnRefusal: true)
        case .awaitShare:
            break
        case .sameRole(let role):
            phase = .failed(.sameRole(role))
        case .bothAccepting:
            phase = .failed(.bothAccepting)
        }
    }

    func makeShare(ownerRole: Role, handsOverOnRefusal: Bool) {
        phase = .sharing
        Task {
            do {
                let paired = try PartnershipState().establishingPairing(ownerRole: ownerRole)
                let share = try await PartnershipShare.makeShare(initialState: paired)
                outcome = Outcome(rootRecordID: share.rootRecordID, isOwner: true)
                try multipeer?.send(share.url.absoluteString)
                // 完了にするのは ACK を受け取った時点。
            } catch let error where handsOverOnRefusal && FailureReason(error) == .iCloudFull {
                // ファミリー共有の iCloud+ に空きがあっても、自分の使用量が無料の 5GB を超えていると断られる（FB16214848）。
                Logger.pairing.error("hand over: \(error, privacy: .public)")
                handOver(ownerRole)
            } catch {
                fail(with: error)
            }
        }
    }

    func handOver(_ role: Role) {
        do {
            try multipeer?.send(Self.handOverPrefix + role.rawValue)
            phase = .handedOver
        } catch {
            fail(with: error)
        }
    }

    func acceptShare(from url: URL) {
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

    func handleReceived(_ text: String) {
        if let partner = Self.choice(from: text) {
            handlePartnerChoice(partner)
            return
        }
        switch text {
        case Self.failureMessage:
            guard phase == .connected || phase == .sharing || phase == .handedOver else { return }
            outcome = nil
            phase = .failed(phase == .handedOver ? .iCloudFull : .partnerFailed)
            tearDown()
        case Self.ackMessage:
            guard phase == .sharing, outcome?.isOwner == true else { return }
            phase = .done
            tearDown()
        case _ where text.hasPrefix(Self.handOverPrefix):
            guard phase == .connected,
                  let partnerRole = Role(rawValue: String(text.dropFirst(Self.handOverPrefix.count))) else { return }
            makeShare(ownerRole: partnerRole.counterpart, handsOverOnRefusal: false)
        default:
            guard phase == .connected || phase == .handedOver, let url = URL(string: text) else { return }
            acceptShare(from: url)
        }
    }

    func fail(with error: any Error) {
        Logger.pairing.error("\(String(describing: self.choice), privacy: .public): \(error, privacy: .public)")
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
