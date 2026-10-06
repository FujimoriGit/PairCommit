//
//  RemotePairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import Foundation
import Observation

/// 離れた相手と、招待リンクでペアを作る。前回の招待の途中があれば、そこから再開する。
@MainActor
@Observable
public final class RemotePairing {
    public enum Phase: Equatable, Sendable {
        case idle
        case inviting
        case joining
    }

    public private(set) var invitationURL: URL?
    public private(set) var failure: PairingFailure?
    public private(set) var isCancelling = false

    private let inviting: any PartnershipInviting
    private var step: Step?
    private var polling: Task<(any PairedShare)?, Never>?
    private var withdrawal: Withdrawal?

    public init(inviting: any PartnershipInviting) {
        self.inviting = inviting
        step = inviting.savedStage().map(Step.init)
        withdrawal = inviting.savedWithdrawal()
    }

    public var isCreatingLink: Bool {
        guard case .sending = step else { return false }
        return withdrawal == nil
    }

    /// 招待している側が選んだ役割。招待リンクに添える文で、相手の役割を伝えるのに使う。
    public var ownerRole: Role? {
        switch step {
        case .sending(let ownerRole), .sent(let ownerRole): ownerRole
        case .accepting, .joined, nil: nil
        }
    }

    public var phase: Phase {
        switch step {
        case .sending, .sent: .inviting
        case .accepting, .joined: .joining
        // 送る途中は端末に残らないので、その段階でやめた後始末だけが開き直したあとに残る。
        case nil: withdrawal == nil ? .idle : .inviting
        }
    }

    public func invite(ownerRole: Role) {
        reset()
        step = .sending(ownerRole: ownerRole)
    }

    public func receive(_ link: URL) {
        reset()
        step = .accepting(link)
    }

    public func retry() {
        failure = nil
    }

    /// 相手とペアができるまで進める。やめる後始末が残っていれば、相手は待たずに後始末をやり直す。
    /// - Returns: できたペア。失敗したときは `failure` に入れて nil を返す。
    public func run() async -> (any PairedShare)? {
        if withdrawal != nil {
            await cancel()
            return nil
        }
        let polling = Task { await advance() }
        self.polling = polling
        let outcome = await withTaskCancellationHandler { await polling.value } onCancel: { polling.cancel() }
        // やめたときは、止まる前にペアができていても、それは cancel が終わらせる。
        return polling.isCancelled ? nil : outcome
    }

    /// 招待をやめ、作った共有を消すか、参加した共有から抜ける。止める前にペアができていたら、ペアごと終わらせる。
    /// 失敗したときは `failure` に入れて、招待の途中に留まる。
    public func cancel() async {
        isCancelling = true
        defer { isCancelling = false }
        let pending: Withdrawal
        if let withdrawal {
            pending = withdrawal
        } else {
            // 止まり切るのを待ってから後始末に入る。並んで走ると、後始末のあとで参加や共有の作成が通ってしまう。
            polling?.cancel()
            let paired = await polling?.value ?? nil
            polling = nil
            guard let cleanup = paired == nil ? invitationWithdrawal : .pair else {
                reset()
                return
            }
            inviting.save(cleanup)
            withdrawal = cleanup
            pending = cleanup
        }
        do throws(PairingFailure) {
            try await perform(pending)
        } catch {
            failure = error
            return
        }
        reset()
    }

    public func reset() {
        inviting.clearSaved()
        step = nil
        invitationURL = nil
        failure = nil
        withdrawal = nil
    }
}

// MARK: - Private

private extension RemotePairing {
    enum Step: Equatable {
        case sending(ownerRole: Role)
        case sent(ownerRole: Role)
        case accepting(URL)
        case joined

        init(_ stage: InvitationStage) {
            switch stage {
            case .sent(let ownerRole): self = .sent(ownerRole: ownerRole)
            case .joined: self = .joined
            }
        }
    }

    static let pollingInterval: Duration = .seconds(5)

    var invitationWithdrawal: Withdrawal? {
        switch step {
        case .sending, .sent: .invitation
        case .joined: .membership
        case .accepting, nil: nil
        }
    }

    static func waitForNextPoll() async -> Bool {
        do {
            try await Task.sleep(for: pollingInterval)
            return true
        } catch {
            return false
        }
    }

    func perform(_ withdrawal: Withdrawal) async throws(PairingFailure) {
        switch withdrawal {
        case .invitation:
            try await inviting.withdraw()
        case .membership:
            try await inviting.leave()
        case .pair:
            try await inviting.endPair()
        }
    }

    func advance() async -> (any PairedShare)? {
        do throws(PairingFailure) {
            switch step {
            case .sending(let ownerRole), .sent(let ownerRole):
                return try await awaitGuest(ownerRole: ownerRole)
            case .accepting, .joined:
                return try await awaitHost()
            case nil:
                return nil
            }
        } catch {
            // やめたり画面を離れたりして打ち切られたときは、失敗として出さない。
            if !Task.isCancelled {
                failure = error
            }
            return nil
        }
    }

    func awaitGuest(ownerRole: Role) async throws(PairingFailure) -> (any PairedShare)? {
        if case .sending = step {
            invitationURL = try await inviting.send()
            guard !Task.isCancelled else { return nil }
            step = .sent(ownerRole: ownerRole)
            inviting.save(.sent(ownerRole: ownerRole))
        }
        while true {
            let progress = try await inviting.advance(ownerRole: ownerRole)
            guard !Task.isCancelled else { return nil }
            switch progress {
            case .waiting(let url):
                invitationURL = url
            case .paired(let share):
                return share
            }
            guard await Self.waitForNextPoll() else { return nil }
        }
    }

    func awaitHost() async throws(PairingFailure) -> (any PairedShare)? {
        if case .accepting(let link) = step {
            // 参加が通ったら、打ち切られていても抜けられるように残す。
            try await inviting.join(link)
            step = .joined
            inviting.save(.joined)
        }
        guard case .joined = step else { return nil }
        while true {
            let joined = try await inviting.advanceJoining()
            guard !Task.isCancelled else { return nil }
            if let joined {
                return joined
            }
            guard await Self.waitForNextPoll() else { return nil }
        }
    }
}
