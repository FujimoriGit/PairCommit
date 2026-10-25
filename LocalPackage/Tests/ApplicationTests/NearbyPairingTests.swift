//
//  NearbyPairingTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Application
import Domain
import Foundation
import Testing

@MainActor
struct NearbyPairingTests {

    @Test("2台とも同じ役割を選ぶと、ペアは保存されず、役割の重複でペアリングが失敗する", arguments: Role.allCases)
    func choosingTheSameRoleOnBothDevicesSavesNoPair(chosen: Role) async {
        // Given
        let (pairing, channel, sharing) = Self.started(as: chosen)

        // When
        channel.receive(.received(Partner.choosing(chosen)))

        // Then
        #expect(await eventually { pairing.phase == .failed(.sameRole(chosen)) })
        #expect(sharing.makeShareCalls == 0)
    }

    @Test("2台とも同じ役割を選ぶと、ペアリングが失敗し、役割の重複が診断の記録に残る")
    func choosingTheSameRoleOnBothDevicesIsRecorded() async {
        // Given
        let failures = RecordedFailures()
        let (pairing, channel, _) = Self.started(as: .manager, failures: failures)

        // When
        channel.receive(.received(Partner.choosing(.manager)))

        // Then
        #expect(await eventually { pairing.phase == .failed(.sameRole(.manager)) })
        #expect(failures.recorded.contains { $0 as? NearbyPairing.Failure == .sameRole(.manager) })
    }

    @Test("近くの端末を探すことが許可されていないと、許可が要るとしてペアリングが失敗する")
    func pairingFailsWithoutPermissionToSearchNearby() async {
        // Given
        let (pairing, channel, _) = Self.started(as: .manager)

        // When
        channel.receive(.notPermitted)

        // Then
        #expect(await eventually { pairing.phase == .failed(.external(.nearbyNotPermitted)) })
    }

    @Test("相手とつながったあとで近くの端末を探すことが許可されていないと分かると、相手にペアリングの失敗を知らせる")
    func partnerIsToldOfTheFailureWhenPermissionIsMissingAfterConnecting() async {
        // Given
        let (pairing, channel, _) = Self.started(as: .manager)

        // When
        channel.receive(.notPermitted)

        // Then
        #expect(await eventually { channel.sent.contains(Partner.failure) })
        withExtendedLifetime(pairing) {}
    }

    @Test("自分の側でペアを保存する容量が足りなくても、相手の側でペアを保存して、ペアリングが完了する")
    func pairingCompletesOnThePartnersSideWhenYoursLacksSpace() async {
        // Given
        let (pairing, channel, sharing) = Self.started(as: .manager)
        sharing.failure = .storageFull
        channel.receive(.received(Partner.choosing(.player)))
        #expect(await eventually { channel.sent.contains(Partner.handingOver(.manager)) })

        // When
        channel.receive(.received(Partner.savedPair))

        // Then
        #expect(await eventually { pairing.phase == .done })
        #expect(pairing.outcome?.isOwner == false)
    }

    @Test("自分の側でペアを保存したときは、相手がそのペアに参加した時点でペアリングが完了する")
    func pairingCompletesOnceThePartnerJoins() async {
        // Given
        let (pairing, channel, sharing) = Self.started(as: .manager)
        channel.receive(.received(Partner.choosing(.player)))
        #expect(await eventually { channel.sent.contains(sharing.url.absoluteString) })

        // When
        channel.receive(.received(Partner.acknowledgement))

        // Then
        #expect(await eventually { pairing.phase == .done })
        #expect(pairing.outcome?.isOwner == true)
    }

    @Test("挑む人を選んだ側は、見届ける人を選んだ相手が保存したペアに参加して、ペアリングが完了する")
    func playerCompletesPairingByJoiningTheManagersPair() async {
        // Given
        let (pairing, channel, sharing) = Self.started(as: .player)
        channel.receive(.received(Partner.choosing(.manager)))

        // When
        channel.receive(.received(sharing.url.absoluteString))

        // Then
        #expect(await eventually { pairing.phase == .done })
    }

    @Test("ペアを保存している途中でやめたら、ペアリングは完了せず、保存したペアは相手に送られない")
    func cancellingWhileSavingThePairNeitherCompletesPairingNorSendsThePair() async {
        // Given
        let (pairing, channel, sharing) = Self.started(as: .manager)
        sharing.hold()
        channel.receive(.received(Partner.choosing(.player)))
        #expect(await eventually { sharing.isHeld })

        // When
        pairing.reset()
        sharing.release()

        // Then
        #expect(await eventually { sharing.returnedCount == 1 })
        await Task.yield()
        #expect(pairing.outcome == nil)
        #expect(pairing.phase == .idle)
        #expect(!channel.sent.contains(sharing.url.absoluteString))
    }
}

// MARK: - Private

private extension NearbyPairingTests {
    static func started(
        as role: Role,
        failures: RecordedFailures = .init()
    ) -> (NearbyPairing, FakeChannel, FakeSharing) {
        let channel = FakeChannel()
        let sharing = FakeSharing()
        let pairing = NearbyPairing(sharing: sharing, failures: failures, makeChannel: { channel })
        pairing.start(as: role)
        channel.receive(.connected)
        return (pairing, channel, sharing)
    }
}

/// 相手の端末が送ってくる文字列。
private enum Partner {
    static let acknowledgement = "paircommit://ack"
    static let failure = "paircommit://failed"
    static let savedPair = "file:///partners-pair"

    static func choosing(_ role: Role) -> String {
        "paircommit://role/\(role.rawValue)"
    }

    static func handingOver(_ role: Role) -> String {
        "paircommit://hand-over/\(role.rawValue)"
    }
}

private final class FakeChannel: NearbyChannel {
    let events: AsyncStream<NearbyEvent>
    private(set) var sent: [String] = []

    private let continuation: AsyncStream<NearbyEvent>.Continuation

    init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    func receive(_ event: NearbyEvent) {
        continuation.yield(event)
    }

    func start() {}

    func stop() {
        continuation.finish()
    }

    func send(_ text: String) throws(PairingFailure) {
        sent.append(text)
    }
}

/// 共有を作るのを止めておける。作っている間にやめた状況を作るために使う。
@MainActor
private final class FakeSharing: PartnershipSharing {
    nonisolated let url = URL(fileURLWithPath: "/share")
    var failure: PairingFailure?
    private(set) var makeShareCalls = 0
    private(set) var returnedCount = 0

    private var held = false
    private var waiting: CheckedContinuation<Void, Never>?

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

    func makeShare(initialState: PartnershipState) async throws(PairingFailure) -> (url: URL, share: any PairedShare) {
        makeShareCalls += 1
        if held {
            await withCheckedContinuation { waiting = $0 }
        }
        returnedCount += 1
        if let failure {
            throw failure
        }
        return (url, StubShare(isOwner: true))
    }

    func acceptShare(from url: URL) async throws(PairingFailure) -> any PairedShare {
        StubShare(isOwner: false)
    }

    nonisolated func savedShare() -> (any PairedShare)? {
        nil
    }

    func remainingShare() async throws(PairingFailure) -> (any PairedShare)? {
        nil
    }

    nonisolated func declineRemainingShare() {}

    nonisolated func clearSavedShare() {}
}
