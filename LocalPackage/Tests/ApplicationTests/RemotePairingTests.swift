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

    @Test("招待をやめたときにもう相手が参加していたら、招待だけでなく、できたペアも終わらせる")
    func cancellingAfterThePairFormedEndsThePair() async {
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

    @Test("招待をやめ終わるまでは、やめている途中だと出る")
    func cancellationStaysVisibleUntilItFinishes() async {
        // Given
        let inviting = FakeInviting()
        let pairing = RemotePairing(inviting: inviting)
        pairing.invite(ownerRole: .manager)
        inviting.hold()
        let cancelling = Task { await pairing.cancel() }
        #expect(await eventually { inviting.isHeld })
        #expect(pairing.isCancelling)

        // When
        inviting.release()
        await cancelling.value

        // Then
        #expect(!pairing.isCancelling)
    }

    @Test("招待リンクを用意できなかったら、招待リンクを作れなかったと出る")
    func failingToSendIsAFailureWhileCreatingTheLink() async {
        // Given
        let inviting = FakeInviting()
        inviting.sendFailure = .offline
        let pairing = RemotePairing(inviting: inviting)
        pairing.invite(ownerRole: .manager)

        // When
        _ = await pairing.run()

        // Then
        #expect(pairing.failure == .offline)
        #expect(pairing.isCreatingLink)
    }

    @Test("招待リンクを用意している途中でやめて、やめるのに失敗したら、招待リンクを作れなかったとは出ない")
    func failingToCancelIsNotAFailureWhileCreatingTheLink() async {
        // Given
        let inviting = FakeInviting()
        inviting.cleanupFailure = .offline
        let pairing = RemotePairing(inviting: inviting)
        pairing.invite(ownerRole: .manager)

        // When
        await pairing.cancel()

        // Then
        #expect(pairing.failure == .offline)
        #expect(!pairing.isCreatingLink)
    }

    @Test("招待をやめるのに失敗してもう一度試すと、相手の参加を待つところへは戻らず、やめるのをやり直す")
    func tryingAgainAfterFailingToCancelCancelsAgain() async {
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

    @Test("招待をやめている途中でアプリを開き直したら、相手の参加を待たずに、やめるのを続ける")
    func reopeningWhileCancellingKeepsCancelling() async {
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

    @Test("招待リンクを送ったあとでアプリを開き直したら、リンクを作り直さずに相手の参加を待つ")
    func reopeningAfterSendingTheLinkWaitsForThePartner() async {
        // Given
        let inviting = FakeInviting(savedStage: .sent(ownerRole: .manager))
        inviting.progress = .paired(StubShare(isOwner: true))
        let pairing = RemotePairing(inviting: inviting)

        // When
        let paired = await pairing.run()

        // Then
        #expect(pairing.phase == .inviting)
        #expect(paired != nil)
        #expect(inviting.sendCalls == 0)
    }

    @Test("招待リンクで参加したあとでアプリを開き直したら、参加し直さずに招待した相手を待つ")
    func reopeningAfterJoiningWaitsForTheInviter() async {
        // Given
        let inviting = FakeInviting(savedStage: .joined)
        inviting.joinedShare = StubShare(isOwner: false)
        let pairing = RemotePairing(inviting: inviting)

        // When
        let paired = await pairing.run()

        // Then
        #expect(pairing.phase == .joining)
        #expect(paired != nil)
        #expect(inviting.joinCalls == 0)
    }

    @Test("相手の参加を待つのを途中で打ち切ったら、そのあと相手が参加しても、そのペアでは使い始めない")
    func stoppingTheWaitStartsNoPair() async {
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

/// 相手の参加を確かめるのと、招待を消すのを止めておける。その途中の状況を作るために使う。
@MainActor
private final class FakeInviting: PartnershipInviting {
    nonisolated let link = URL(fileURLWithPath: "/invitation")
    var progress: InvitationProgress
    var joinedShare: (any PairedShare)?
    var sendFailure: PairingFailure?
    var cleanupFailure: PairingFailure?
    private(set) var sendCalls = 0
    private(set) var advanceCalls = 0
    private(set) var joinCalls = 0
    private(set) var withdrawCalls = 0
    private(set) var endPairCalls = 0

    private nonisolated let restoredStage: InvitationStage?
    private nonisolated let restoredWithdrawal: Withdrawal?
    private var held = false
    private var waiting: CheckedContinuation<Void, Never>?

    init(savedStage: InvitationStage? = nil, savedWithdrawal: Withdrawal? = nil) {
        restoredStage = savedStage
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
        sendCalls += 1
        if let sendFailure {
            throw sendFailure
        }
        return link
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
        if held {
            await withCheckedContinuation { waiting = $0 }
        }
        if let cleanupFailure {
            throw cleanupFailure
        }
    }

    func join(_ link: URL) async throws(PairingFailure) {
        joinCalls += 1
    }

    func advanceJoining() async throws(PairingFailure) -> (any PairedShare)? {
        joinedShare
    }

    func leave() async throws(PairingFailure) {}

    func endPair() async throws(PairingFailure) {
        endPairCalls += 1
        if let cleanupFailure {
            throw cleanupFailure
        }
    }

    nonisolated func savedStage() -> InvitationStage? {
        restoredStage
    }

    nonisolated func savedWithdrawal() -> Withdrawal? {
        restoredWithdrawal
    }

    nonisolated func save(_ stage: InvitationStage) {}

    nonisolated func save(_ withdrawal: Withdrawal) {}

    nonisolated func clearSaved() {}
}
