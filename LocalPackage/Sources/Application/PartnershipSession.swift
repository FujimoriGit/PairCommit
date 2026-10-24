//
//  PartnershipSession.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Domain
import Foundation
import Observation

/// 起動してから、相手とペアを組み、そのペアを使い終えるまで。
@MainActor
@Observable
public final class PartnershipSession {
    public enum Stage {
        case choosingRole(Interruption?)
        case pairingNearby
        case pairingRemotely
        case connecting(SyncFailure?)
        case paired(PartnershipStore)
    }

    /// 役割の選択に戻った理由。
    public enum Interruption: Equatable, Sendable {
        case partnershipEnded
        case pairingResultMissing
        case partnerSetupMissing
    }

    public enum LinkRefusal: Error, Equatable {
        case alreadyPaired
        case pairingInProgress
    }

    public let nearby: NearbyPairing
    public let remote: RemotePairing
    /// 役割を選び、ペアの組み方を選んでいる途中の役割。
    public var chosenRole: Role?

    private let sharing: any PartnershipSharing
    private let nudges: any NudgeNotifying
    private let partnerActions: any PartnerActionNotifying
    private let knownState: any KnownStateKeeping
    private let nudgeMessage: @Sendable (Nudge, PartnershipState) -> String
    private var connection: Connection

    public init(
        sharing: any PartnershipSharing,
        inviting: any PartnershipInviting,
        nudges: any NudgeNotifying,
        partnerActions: any PartnerActionNotifying,
        knownState: any KnownStateKeeping,
        nudgeMessage: @escaping @Sendable (Nudge, PartnershipState) -> String,
        makeNearbyChannel: @escaping @MainActor () -> any NearbyChannel
    ) {
        self.sharing = sharing
        self.nudges = nudges
        self.partnerActions = partnerActions
        self.knownState = knownState
        self.nudgeMessage = nudgeMessage
        nearby = NearbyPairing(sharing: sharing, makeChannel: makeNearbyChannel)
        remote = RemotePairing(inviting: inviting)
        connection = sharing.savedShare().map { .connecting($0, isResumed: true, failure: nil) } ?? .unpaired(nil)
    }

    public var stage: Stage {
        switch connection {
        case .paired(_, let store): .paired(store)
        // ペアができてからつながるまでは、ペアリングの画面のまま待つ。
        case _ where nearby.phase != .idle: .pairingNearby
        case .connecting(_, _, let failure): .connecting(failure)
        case .unpaired where remote.phase != .idle: .pairingRemotely
        case .unpaired(let interruption): .choosingRole(interruption)
        }
    }

    public var store: PartnershipStore? {
        guard case .paired(_, let store) = connection else { return nil }
        return store
    }

    /// 端末に前のペアが残っていなければ、端末の外に残っているペアを探し、見つかればつなぐ段階に入る。
    /// 組み方を選んでいる途中や、探している間に組み始めたときは、見つかっても引き戻さない。
    public func resumeRemainingPairing() async {
        guard isChoosingRole, let remaining = try? await sharing.remainingShare(), isChoosingRole else { return }
        remaining.save()
        connection = .connecting(remaining, isResumed: true, failure: nil)
    }

    /// つなぐ段階に入ったペアにつなぐ。つなげずに失敗しているときは何もしない。
    public func connect() async {
        guard case .connecting(let share, let isResumed, nil) = connection else { return }
        await connect(to: share, isResumed: isResumed)
    }

    public func retryConnecting() async {
        guard case .connecting(let share, let isResumed, .some(_)) = connection else { return }
        await connect(to: share, isResumed: isResumed)
    }

    /// 前のペアへのつなぎ直しをやめ、役割の選択に戻る。
    public func startOver() async {
        sharing.declineRemainingShare()
        await returnToRolePicker(with: nil)
    }

    public func pairNearby(as role: Role) {
        leaveRolePicker()
        nearby.start(as: role)
    }

    public func finishNearbyPairing() async {
        guard nearby.phase == .done else { return }
        guard let share = nearby.outcome else {
            await returnToRolePicker(with: .pairingResultMissing)
            return
        }
        share.save()
        await connect(to: share, isResumed: false)
    }

    public func invite(ownerRole: Role) {
        leaveRolePicker()
        remote.invite(ownerRole: ownerRole)
    }

    public func accept(_ link: URL) throws(LinkRefusal) {
        switch connection {
        case .connecting, .paired:
            throw .alreadyPaired
        case .unpaired where remote.phase != .idle || nearby.phase != .idle:
            throw .pairingInProgress
        case .unpaired:
            leaveRolePicker()
            remote.receive(link)
        }
    }

    public func pairRemotely() async {
        guard remote.failure == nil else { return }
        guard let share = await remote.run() else {
            if remote.phase == .idle {
                await returnToRolePicker(with: nil)
            }
            return
        }
        share.save()
        connection = .connecting(share, isResumed: false, failure: nil)
        remote.reset()
    }

    public func cancelRemotePairing() async {
        await remote.cancel()
        guard remote.phase == .idle else { return }
        await returnToRolePicker(with: nil)
    }

    /// ペアの状態が変わったら呼ぶ。ペアが終わっていれば役割の選択に戻り、続いていれば催促の通知を揃える。
    /// - Parameter isActive: 画面が前面にあるか。前面にあるときだけ、相手の操作を知らせ終えたものとして残す。
    public func followStateChange(isActive: Bool) async {
        guard case .paired(_, let store) = connection else { return }
        let state = store.state
        guard state.pairing != nil else {
            await returnToRolePicker(with: .partnershipEnded)
            return
        }
        if isActive {
            knownState.keep(state)
        }
        let message = nudgeMessage
        await nudges.post(for: store.role, in: state) { message($0, state) }
    }

    /// いまの状態を、相手の操作を知らせ終えたものとして残す。画面が前面に戻ったときに呼ぶ。
    public func markCurrentStateSeen() {
        guard case .paired(_, let store) = connection else { return }
        knownState.keep(store.state)
    }

    /// 相手の側でもペアを終わらせ、役割の選択に戻る。前に組んで残っているペアも終わらせる。
    public func endPartnership() async throws(PairingFailure) {
        guard case .paired(let share, _) = connection else { return }
        // いまのペアを先に終わらせると、残りで失敗したときに、終わったペアを出したまま止まる。
        try await share.endOtherPairs()
        try await share.end()
        await returnToRolePicker(with: nil)
    }
}

extension PartnershipSession.Stage: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.choosingRole(lhs), .choosingRole(rhs)): lhs == rhs
        case (.pairingNearby, .pairingNearby), (.pairingRemotely, .pairingRemotely): true
        case let (.connecting(lhs), .connecting(rhs)): lhs == rhs
        case let (.paired(lhs), .paired(rhs)): lhs === rhs
        case (.choosingRole, _), (.pairingNearby, _), (.pairingRemotely, _), (.connecting, _), (.paired, _): false
        }
    }
}

// MARK: - Private

private extension PartnershipSession {
    enum Connection {
        case unpaired(Interruption?)
        case connecting(any PairedShare, isResumed: Bool, failure: SyncFailure?)
        case paired(any PairedShare, PartnershipStore)
    }

    var isChoosingRole: Bool {
        guard case .unpaired = connection else { return false }
        return nearby.phase == .idle && remote.phase == .idle && chosenRole == nil
    }

    func leaveRolePicker() {
        connection = .unpaired(nil)
        chosenRole = nil
    }

    func connect(to share: any PairedShare, isResumed: Bool) async {
        connection = .connecting(share, isResumed: isResumed, failure: nil)
        let started: PartnershipStore?
        do throws(SyncFailure) {
            started = try await PartnershipStore(starting: share)
        } catch {
            connection = .connecting(share, isResumed: isResumed, failure: error)
            nearby.reset()
            return
        }
        guard let started else {
            await returnToRolePicker(with: isResumed ? .partnershipEnded : .partnerSetupMissing)
            return
        }
        await nudges.requestPermission()
        connection = .paired(share, started)
        if !isResumed {
            try? await share.endOtherPairs()
        }
    }

    func returnToRolePicker(with interruption: Interruption?) async {
        await nudges.withdrawAll()
        await partnerActions.withdrawAll()
        knownState.forget()
        sharing.clearSavedShare()
        remote.reset()
        connection = .unpaired(interruption)
        nearby.reset()
    }
}
