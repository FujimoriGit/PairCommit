//
//  NearbyPairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Domain
import Foundation
import Observation

/// 近くにいる相手と、ペアの入った共有を受け渡す。
@MainActor
@Observable
public final class NearbyPairing {
    public enum Phase: Equatable, Sendable {
        case idle
        case searching
        case connected
        case sharing
        case handedOver
        case done
        case failed(PairingFailure)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var outcome: (any PairedShare)?

    private let sharing: any PartnershipSharing
    private let makeChannel: @MainActor () -> any NearbyChannel
    private var channel: (any NearbyChannel)?
    private var eventTask: Task<Void, Never>?
    private var choice: PairingChoice = .invitation

    public init(sharing: any PartnershipSharing, makeChannel: @escaping @MainActor () -> any NearbyChannel) {
        self.sharing = sharing
        self.makeChannel = makeChannel
    }

    public func start(with choice: PairingChoice) {
        guard phase == .idle else { return }
        self.choice = choice
        phase = .searching

        let channel = makeChannel()
        self.channel = channel
        let events = channel.events
        eventTask = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }
        channel.start()
    }

    public func reset() {
        tearDown()
        outcome = nil
        phase = .idle
    }
}

// MARK: - Private

private extension NearbyPairing {
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

    static func initialState(ownerRole: Role) throws(PairingFailure) -> PartnershipState {
        do throws(DomainError) {
            return try PartnershipState().establishingPairing(ownerRole: ownerRole)
        } catch {
            throw .unexpected
        }
    }

    func handle(_ event: NearbyEvent) {
        switch event {
        case .connected:
            handleConnected()
        case .received(let text):
            handleReceived(text)
        case .disconnected:
            switch phase {
            case .connected, .sharing, .handedOver:
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
        do throws(PairingFailure) {
            try channel?.send(Self.message(for: choice))
        } catch {
            fail(with: error)
        }
    }

    func handlePartnerChoice(_ partner: PairingChoice) {
        // 接続の知らせと受信のどちらが先に届くかは、文書で約束されていない。
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
        let channel = channel
        Task {
            do throws(PairingFailure) {
                let made = try await sharing.makeShare(initialState: Self.initialState(ownerRole: ownerRole))
                // 待っているあいだに、切断や取り消しで終わっていたり、選び直されていたりすることがある。
                guard isSharing(on: channel) else { return }
                outcome = made.share
                try channel?.send(made.url.absoluteString)
                // 完了にするのは ACK を受け取った時点。
            } catch .storageFull where handsOverOnRefusal {
                guard isSharing(on: channel) else { return }
                // ファミリー共有の iCloud+ に空きがあっても、自分の使用量が無料の 5GB を超えていると断られる（FB16214848）。
                handOver(ownerRole)
            } catch {
                guard isSharing(on: channel) else { return }
                fail(with: error)
            }
        }
    }

    func isSharing(on channel: (any NearbyChannel)?) -> Bool {
        self.channel === channel && phase == .sharing
    }

    func handOver(_ role: Role) {
        do throws(PairingFailure) {
            try channel?.send(Self.handOverPrefix + role.rawValue)
            phase = .handedOver
        } catch {
            fail(with: error)
        }
    }

    func acceptShare(from url: URL) {
        phase = .sharing
        let channel = channel
        Task {
            do throws(PairingFailure) {
                let share = try await sharing.acceptShare(from: url)
                guard isSharing(on: channel) else { return }
                outcome = share
                try channel?.send(Self.ackMessage)
                // すぐ切断すると ACK が届く前にセッションが落ちることがある。
                phase = .done
            } catch {
                guard isSharing(on: channel) else { return }
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
            phase = .failed(phase == .handedOver ? .storageFull : .partnerFailed)
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

    func fail(with failure: PairingFailure) {
        outcome = nil
        phase = .failed(failure)
        // 知らせないと、相手には接続が切れたとしか見えない。すぐ切ると届く前にセッションが落ちるので、
        // 切るのは相手が受け取って切断したとき。
        do throws(PairingFailure) {
            try channel?.send(Self.failureMessage)
        } catch {
            tearDown()
        }
    }

    func tearDown() {
        eventTask?.cancel()
        eventTask = nil
        channel?.stop()
        channel = nil
    }
}
