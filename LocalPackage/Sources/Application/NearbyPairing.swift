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
        case failed(Failure)
    }

    public enum Failure: Error, Equatable, Sendable {
        case sameRole(Role)
        case partnerFailed
        case external(PairingFailure)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var outcome: (any PairedShare)?

    private let sharing: any PartnershipSharing
    private let failures: any FailureRecording
    private let makeChannel: @MainActor () -> any NearbyChannel
    private let partnerJoinCheckInterval: Duration
    private var channel: (any NearbyChannel)?
    private var eventTask: Task<Void, Never>?
    private var shareTask: Task<Void, Never>?
    private var preparing: Task<Result<(url: URL, share: any PairedShare), PairingFailure>, Never>?
    private var role: Role?

    /// - Parameter partnerJoinCheckInterval: 招待の URL を渡したあとに近くの通信が切れたとき、相手が参加したかを確かめ直す間隔。
    public init(
        sharing: any PartnershipSharing,
        failures: any FailureRecording,
        makeChannel: @escaping @MainActor () -> any NearbyChannel,
        partnerJoinCheckInterval: Duration = .seconds(3)
    ) {
        self.sharing = sharing
        self.failures = failures
        self.makeChannel = makeChannel
        self.partnerJoinCheckInterval = partnerJoinCheckInterval
    }

    public func start(as role: Role) {
        guard phase == .idle else { return }
        self.role = role
        phase = .searching
        if role == .manager {
            prepareShare(ownerRole: role)
        }
        openChannel()
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
    static let rolePrefix = "paircommit://role/"
    static let handOverPrefix = "paircommit://hand-over/"
    static let partnerJoinChecks = 5

    static func role(from message: String) -> Role? {
        guard message.hasPrefix(rolePrefix) else { return nil }
        return Role(rawValue: String(message.dropFirst(rolePrefix.count)))
    }

    static func initialState(ownerRole: Role) throws(PairingFailure) -> PartnershipState {
        do throws(PairingEstablishmentError) {
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
            case .connected, .handedOver:
                failing(.external(.disconnected))
                tearDown()
            case .sharing:
                failures.record(Failure.external(.disconnected), during: "nearby handle(_:) sharing")
                // 共有を作っている途中と参加している途中は、その結果で決まる。
                guard let share = outcome, share.isOwner else { return }
                confirmPartnerJoined(share)
            case .done, .failed:
                // 完了後や、失敗を知らせたあとの切断は正常。
                tearDown()
            case .searching:
                // 見つけた相手とつなぐのに失敗している。開き直さないと、同じ相手を二度目は見つけない。
                closeChannel()
                openChannel()
            case .idle:
                break
            }
        case .failed:
            failing(.external(.nearbyUnavailable))
            tearDown()
        case .notPermitted:
            switch phase {
            case .idle, .searching, .connected, .sharing, .handedOver:
                fail(with: .nearbyNotPermitted)
            case .done, .failed:
                break
            }
        }
    }

    func handleConnected() {
        guard let role else { return }
        if phase == .searching {
            phase = .connected
        }
        do throws(PairingFailure) {
            try channel?.send(Self.rolePrefix + role.rawValue)
        } catch {
            fail(with: error)
        }
    }

    func handlePartnerRole(_ partnerRole: Role) {
        // 接続の知らせと受信のどちらが先に届くかは、文書で約束されていない。
        guard let role, phase == .searching || phase == .connected else { return }
        phase = .connected
        // 止めるときは、相手も同じ判定で止まるので知らせない。すぐ切ると、こちらの送信が届く前にセッションが落ちることがある。
        if role == partnerRole {
            failing(.sameRole(role))
        } else if role == .manager {
            makeShare(ownerRole: role, handsOverOnRefusal: true)
        }
    }

    func openChannel() {
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

    @discardableResult
    func prepareShare(ownerRole: Role) -> Task<Result<(url: URL, share: any PairedShare), PairingFailure>, Never> {
        let sharing = sharing
        let task = Task { () -> Result<(url: URL, share: any PairedShare), PairingFailure> in
            do throws(PairingFailure) {
                return .success(try await sharing.makeShare(initialState: Self.initialState(ownerRole: ownerRole)))
            } catch {
                return .failure(error)
            }
        }
        preparing = task
        return task
    }

    func makeShare(ownerRole: Role, handsOverOnRefusal: Bool) {
        phase = .sharing
        let channel = channel
        let preparedEarly = preparing
        let preparing = preparedEarly ?? prepareShare(ownerRole: ownerRole)
        shareTask = Task {
            do throws(PairingFailure) {
                var prepared = await preparing.value
                if preparedEarly != nil, case .failure(let failure) = prepared, failure != .storageFull {
                    guard isSharing(on: channel) else { return }
                    // 探し始めたときには通らなかった通信が、いまは通ることがある。
                    prepared = await prepareShare(ownerRole: ownerRole).value
                }
                let made = try prepared.get()
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

    func confirmPartnerJoined(_ share: any PairedShare) {
        let channel = channel
        Task {
            var failure = PairingFailure.disconnected
            for check in 1...Self.partnerJoinChecks {
                do throws(PairingFailure) {
                    let joined = try await share.hasPartnerJoined()
                    guard isSharing(on: channel) else { return }
                    if joined {
                        phase = .done
                        tearDown()
                        return
                    }
                    failure = .disconnected
                } catch {
                    guard isSharing(on: channel) else { return }
                    failure = error
                }
                if check < Self.partnerJoinChecks {
                    try? await Task.sleep(for: partnerJoinCheckInterval)
                }
            }
            guard isSharing(on: channel) else { return }
            outcome = nil
            failing(.external(failure))
            tearDown()
        }
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
        shareTask = Task {
            do throws(PairingFailure) {
                let share = try await sharing.acceptShare(from: url)
                guard isSharing(on: channel) else { return }
                outcome = share
                phase = .done
                // すぐ切断すると ACK が届く前にセッションが落ちることがある。
                do throws(PairingFailure) {
                    try channel?.send(Self.ackMessage)
                } catch {
                    tearDown()
                }
            } catch {
                guard isSharing(on: channel) else { return }
                fail(with: error)
            }
        }
    }

    func handleReceived(_ text: String) {
        if let partnerRole = Self.role(from: text) {
            handlePartnerRole(partnerRole)
            return
        }
        switch text {
        case Self.failureMessage:
            guard phase == .connected || phase == .sharing || phase == .handedOver else { return }
            outcome = nil
            failing(phase == .handedOver ? .external(.storageFull) : .partnerFailed)
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

    func fail(with failure: PairingFailure, operation: String = #function) {
        outcome = nil
        failing(.external(failure), operation: operation)
        // 知らせないと、相手には接続が切れたとしか見えない。すぐ切ると届く前にセッションが落ちるので、
        // 切るのは相手が受け取って切断したとき。
        do throws(PairingFailure) {
            try channel?.send(Self.failureMessage)
        } catch {
            tearDown()
        }
    }

    func failing(_ failure: Failure, operation: String = #function) {
        failures.record(failure, during: "nearby \(operation)")
        phase = .failed(failure)
    }

    func tearDown() {
        closeChannel()
        shareTask?.cancel()
        shareTask = nil
        preparing?.cancel()
        preparing = nil
    }

    func closeChannel() {
        eventTask?.cancel()
        eventTask = nil
        channel?.stop()
        channel = nil
    }
}
