//
//  RemotePairingTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Application
import Domain
import Foundation
import Testing

@MainActor
struct RemotePairingTests {

    @Test("やめる前にペアができていたら、招待を消すのではなくペアごと終わらせる")
    func cancelAfterPairingEndsThePair() async {
        // Given
        let inviting = FakeInviting()
        inviting.progress = .paired(StubShare(isOwner: true))
        let pairing = RemotePairing(inviting: inviting)
        pairing.invite(ownerRole: .manager)
        _ = await pairing.run()

        // When
        await pairing.cancel()

        // Then
        #expect(inviting.endPairCalls == 1)
        #expect(inviting.withdrawCalls == 0)
        #expect(pairing.phase == .idle)
    }

    @Test("後始末に失敗したあとにもう一度試すと、相手待ちに戻らず同じ後始末をやり直す")
    func retryAfterFailedCleanupRepeatsTheSameCleanup() async {
        // Given
        let inviting = FakeInviting()
        inviting.progress = .paired(StubShare(isOwner: true))
        inviting.cleanupFailure = .offline
        let pairing = RemotePairing(inviting: inviting)
        pairing.invite(ownerRole: .manager)
        await pairing.cancel()
        inviting.cleanupFailure = nil

        // When
        pairing.retry()
        let paired = await pairing.run()

        // Then
        #expect(paired == nil)
        #expect(inviting.withdrawCalls == 2)
        #expect(inviting.advanceCalls == 0)
        #expect(pairing.phase == .idle)
    }

    @Test("後始末の途中で開き直したら、相手を待たずに後始末を続ける")
    func restoringDuringCleanupContinuesTheCleanup() async {
        // Given
        let inviting = FakeInviting(savedWithdrawal: .invitation)
        inviting.progress = .paired(StubShare(isOwner: true))
        let pairing = RemotePairing(inviting: inviting)

        // When
        let paired = await pairing.run()

        // Then
        #expect(paired == nil)
        #expect(inviting.withdrawCalls == 1)
        #expect(inviting.advanceCalls == 0)
        #expect(pairing.phase == .idle)
    }

    @Test("相手を待っている間に打ち切ったら、そのあとペアができても返さない")
    func cancelledRunDoesNotReturnThePair() async {
        // Given
        let inviting = FakeInviting()
        inviting.progress = .paired(StubShare(isOwner: true))
        inviting.hold()
        let pairing = RemotePairing(inviting: inviting)
        pairing.invite(ownerRole: .manager)
        let running = Task { await pairing.run() }
        #expect(await eventually { inviting.isHeld })

        // When
        running.cancel()
        inviting.release()

        // Then
        #expect(await running.value == nil)
    }
}

/// 相手の参加を確かめるのを止めておける。待っている間に打ち切った状況を作るために使う。
@MainActor
private final class FakeInviting: PartnershipInviting {
    nonisolated let link = URL(fileURLWithPath: "/invitation")
    var progress: InvitationProgress
    var cleanupFailure: PairingFailure?
    private(set) var advanceCalls = 0
    private(set) var withdrawCalls = 0
    private(set) var endPairCalls = 0

    private nonisolated let restoredWithdrawal: Withdrawal?
    private var held = false
    private var waiting: CheckedContinuation<Void, Never>?

    init(savedWithdrawal: Withdrawal? = nil) {
        restoredWithdrawal = savedWithdrawal
        progress = .waiting(link)
    }

    var isHeld: Bool {
        waiting != nil
    }

    func hold() {
        held = true
    }

    func release() {
        held = false
        waiting?.resume()
        waiting = nil
    }

    func send() async throws(PairingFailure) -> URL {
        link
    }

    func advance(ownerRole: Role) async throws(PairingFailure) -> InvitationProgress {
        advanceCalls += 1
        if held {
            await withCheckedContinuation { waiting = $0 }
        }
        return progress
    }

    func withdraw() async throws(PairingFailure) {
        withdrawCalls += 1
        if let cleanupFailure {
            throw cleanupFailure
        }
    }

    func join(_ link: URL) async throws(PairingFailure) {}

    func advanceJoining() async throws(PairingFailure) -> (any PairedShare)? {
        nil
    }

    func leave() async throws(PairingFailure) {}

    func endPair() async throws(PairingFailure) {
        endPairCalls += 1
        if let cleanupFailure {
            throw cleanupFailure
        }
    }

    nonisolated func savedStep() -> InvitationStep? {
        nil
    }

    nonisolated func savedWithdrawal() -> Withdrawal? {
        restoredWithdrawal
    }

    nonisolated func save(_ step: InvitationStep) {}

    nonisolated func save(_ withdrawal: Withdrawal) {}

    nonisolated func clearSaved() {}
}
