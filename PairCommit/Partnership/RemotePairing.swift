//
//  RemotePairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import Foundation
import Observation

/// 離れた相手と、招待リンクでペアを作る。
@MainActor
@Observable
final class RemotePairing {
    enum Phase: Equatable {
        case idle
        case inviting
        case joining
    }

    private(set) var invitationURL: URL?
    private(set) var failure: FailureReason?

    private var step: InvitationStep?
    private var polling: Task<PairedShare?, Never>?
    private var withdrawal: Withdrawal?

    /// 前回の招待の途中から再開する。
    static func restored() -> Self {
        let pairing = Self()
        pairing.step = SavedInvitation.load()
        pairing.withdrawal = SavedInvitation.loadWithdrawal()
        return pairing
    }

    /// やめる後始末が終わっていない。続けるときは `cancel()` を呼ぶ。
    var isWithdrawing: Bool {
        withdrawal != nil
    }

    var phase: Phase {
        switch step {
        case .sending, .sent: .inviting
        case .accepting, .joined: .joining
        // 送る途中は端末に残らないので、その段階でやめた後始末だけが開き直したあとに残る。
        case nil: withdrawal == nil ? .idle : .inviting
        }
    }

    func invite(ownerRole: Role) {
        reset()
        step = .sending(ownerRole: ownerRole)
    }

    func receive(_ link: InvitationLink) {
        reset()
        step = .accepting(link.metadata)
    }

    func retry() {
        failure = nil
    }

    /// 相手とペアができるまで進める。
    /// - Returns: できたペア。失敗したときは `failure` に入れて nil を返す。
    func run() async -> PairedShare? {
        let polling = Task { await advance() }
        self.polling = polling
        let outcome = await withTaskCancellationHandler { await polling.value } onCancel: { polling.cancel() }
        // やめたときは、止まる前にペアができていても、それは cancel が終わらせる。
        return polling.isCancelled ? nil : outcome
    }

    /// 招待をやめ、作った共有を消すか、参加した共有から抜ける。止める前にペアができていたら、ペアごと終わらせる。
    /// 失敗したときは `failure` に入れて、招待の途中に留まる。
    func cancel() async {
        let pending: Withdrawal
        if let withdrawal {
            pending = withdrawal
        } else {
            // 止まり切るのを待ってから後始末に入る。並んで走ると、後始末のあとで参加や共有の作成が通ってしまう。
            polling?.cancel()
            let paired = await polling?.value ?? nil
            polling = nil
            guard let cleanup = paired.map(Withdrawal.pair) ?? invitationWithdrawal else {
                reset()
                return
            }
            SavedInvitation.save(cleanup)
            withdrawal = cleanup
            pending = cleanup
        }
        do {
            try await perform(pending)
        } catch {
            failure = FailureReason(error)
            return
        }
        reset()
    }

    func reset() {
        SavedInvitation.clear()
        step = nil
        invitationURL = nil
        failure = nil
        withdrawal = nil
    }
}

// MARK: - Private

private extension RemotePairing {
    static let pollingInterval: Duration = .seconds(5)

    var invitationWithdrawal: Withdrawal? {
        switch step {
        case .sending, .sent: .invitation
        case .joined(let invitationID): .membership(invitationID: invitationID)
        case .accepting, nil: nil
        }
    }

    func perform(_ withdrawal: Withdrawal) async throws {
        switch withdrawal {
        case .invitation:
            try await PartnershipInvitation.withdraw()
        case .membership(let invitationID):
            try await PartnershipInvitation.leave(invitationID)
        case .pair(let paired):
            try await paired.end()
        }
    }

    func advance() async -> PairedShare? {
        do {
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
                failure = FailureReason(error)
            }
            return nil
        }
    }

    func awaitGuest(ownerRole: Role) async throws -> PairedShare {
        if case .sending = step {
            invitationURL = try await PartnershipInvitation.send()
            try Task.checkCancellation()
            step = .sent(ownerRole: ownerRole)
            SavedInvitation.save(.sent(ownerRole: ownerRole))
        }
        while true {
            let progress = try await PartnershipInvitation.advance(ownerRole: ownerRole)
            try Task.checkCancellation()
            switch progress {
            case .waiting(let url):
                invitationURL = url
            case .paired(let rootRecordID):
                return .init(rootRecordID: rootRecordID, isOwner: true)
            }
            try await Task.sleep(for: Self.pollingInterval)
        }
    }

    func awaitHost() async throws -> PairedShare? {
        if case .accepting(let metadata) = step {
            // 参加が通ったら、打ち切られていても抜けられるように残す。
            let invitationID = try await PartnershipInvitation.join(metadata)
            step = .joined(invitationID: invitationID)
            SavedInvitation.save(.joined(invitationID: invitationID))
        }
        guard case .joined(let invitationID) = step else { return nil }
        while true {
            let joined = try await PartnershipInvitation.advanceJoining(invitationID)
            try Task.checkCancellation()
            if let rootRecordID = joined {
                return .init(rootRecordID: rootRecordID, isOwner: false)
            }
            try await Task.sleep(for: Self.pollingInterval)
        }
    }
}
