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

    @Test("2台とも同じ役割を選ぶと、役割の重複でペアリングが失敗する", arguments: Role.allCases)
    func choosingTheSameRoleOnBothDevicesFailsPairing(chosen: Role) async {
        // Given
        let (pairing, channel, _) = Self.started(as: chosen)

        // When
        channel.receive(.received(Partner.choosing(chosen)))

        // Then
        #expect(await eventually { pairing.phase == .failed(.sameRole(chosen)) })
    }

    @Test("見届ける人が相手を探し始めると、相手とつながる前にペアが保存される")
    func managerSavesThePairBeforeConnecting() async {
        // Given
        let sharing = FakeSharing()
        let pairing = Self.pairing(sharing: sharing, channels: FakeChannels())

        // When
        pairing.start(as: .manager)

        // Then
        #expect(await eventually { sharing.makeShareCalls == 1 })
        #expect(pairing.phase == .searching)
    }

    @Test("見届ける人が探し始めたときにペアを保存できなくても、つながったあとに保存できれば、そのペアを相手に送る")
    func managerSendsThePairSavedAfterConnectingWhenTheEarlySaveFailed() async {
        // Given
        let sharing = FakeSharing()
        sharing.failure = .offline
        let (_, channel, _) = Self.started(as: .manager, sharing: sharing)
        #expect(await eventually { sharing.returnedCount == 1 })
        sharing.failure = nil

        // When
        channel.receive(.received(Partner.choosing(.player)))

        // Then
        #expect(await eventually { channel.sent.contains(sharing.url.absoluteString) })
    }

    @Test("相手を探している間に、見つけた相手とつなぐのに失敗しても、探し直してペアリングが完了する")
    func pairingCompletesAfterAFailedConnectionWhileSearching() async throws {
        // Given
        let sharing = FakeSharing()
        let channels = FakeChannels()
        let pairing = Self.pairing(sharing: sharing, channels: channels)
        pairing.start(as: .player)
        channels.made.first?.receive(.disconnected)
        #expect(await eventually { channels.made.count == 2 })
        let reopened = try #require(channels.made.dropFirst().first)
        reopened.receive(.connected)
        reopened.receive(.received(Partner.choosing(.manager)))

        // When
        reopened.receive(.received(sharing.url.absoluteString))

        // Then
        #expect(await eventually { pairing.phase == .done })
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
        let sharing = FakeSharing()
        sharing.failure = .storageFull
        let (pairing, channel, _) = Self.started(as: .manager, sharing: sharing)
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

    @Test("挑む人は、相手が保存したペアに参加している途中で近くの通信が切れても、参加を終えてペアリングが完了する")
    func playerCompletesPairingWhenDisconnectedWhileJoining() async {
        // Given
        let failures = RecordedFailures()
        let (pairing, channel, sharing) = Self.started(as: .player, failures: failures)
        channel.receive(.received(Partner.choosing(.manager)))
        sharing.hold()
        channel.receive(.received(sharing.url.absoluteString))
        #expect(await eventually { sharing.isHeld })
        channel.receive(.disconnected)
        #expect(await eventually { failures.recorded.contains { $0 as? NearbyPairing.Failure == .external(.disconnected) } })

        // When
        sharing.release()

        // Then
        #expect(await eventually { pairing.phase == .done })
    }

    @Test("見届ける人がペアを保存している途中で近くの通信が切れると、切断でペアリングが失敗する")
    func managerFailsPairingWhenDisconnectedWhileSavingThePair() async {
        // Given
        let failures = RecordedFailures()
        let sharing = FakeSharing()
        sharing.hold()
        let (pairing, channel, _) = Self.started(as: .manager, failures: failures, sharing: sharing)
        channel.receive(.received(Partner.choosing(.player)))
        #expect(await eventually { sharing.isHeld })
        channel.receive(.disconnected)
        #expect(await eventually { failures.recorded.contains { $0 as? NearbyPairing.Failure == .external(.disconnected) } })

        // When
        sharing.release()

        // Then
        #expect(await eventually { pairing.phase == .failed(.external(.disconnected)) })
        #expect(pairing.outcome == nil)
    }

    @Test("見届ける人は、保存したペアを相手に送ったあとで近くの通信が切れても、相手がそのペアに参加していればペアリングが完了する")
    func managerCompletesPairingWhenDisconnectedAfterThePartnerJoins() async {
        // Given
        let (pairing, channel, sharing) = Self.started(as: .manager)
        channel.receive(.received(Partner.choosing(.player)))
        #expect(await eventually { channel.sent.contains(sharing.url.absoluteString) })

        // When
        channel.receive(.disconnected)

        // Then
        #expect(await eventually { pairing.phase == .done })
        #expect(pairing.outcome?.isOwner == true)
    }

    @Test("見届ける人が保存したペアを相手に送ったあとで近くの通信が切れ、相手がそのペアに参加しないままなら、切断でペアリングが失敗する")
    func managerFailsPairingWhenDisconnectedAndThePartnerNeverJoins() async {
        // Given
        let sharing = FakeSharing()
        sharing.partnerJoined = false
        let (pairing, channel, _) = Self.started(as: .manager, sharing: sharing)
        channel.receive(.received(Partner.choosing(.player)))
        #expect(await eventually { channel.sent.contains(sharing.url.absoluteString) })

        // When
        channel.receive(.disconnected)

        // Then
        #expect(await eventually(within: .seconds(2)) { pairing.phase == .failed(.external(.disconnected)) })
        #expect(pairing.outcome == nil)
    }

    @Test("ペアを保存している途中でやめたら、ペアリングは完了せず、保存したペアは相手に送られない")
    func cancellingWhileSavingThePairNeitherCompletesPairingNorSendsThePair() async {
        // Given
        let sharing = FakeSharing()
        sharing.hold()
        let (pairing, channel, _) = Self.started(as: .manager, sharing: sharing)
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

    @Test("挑む人が相手の保存したペアに参加している途中でやめたら、そのペアへの参加は取り消される")
    func cancellingWhileJoiningThePartnersPairCancelsTheJoin() async {
        // Given
        let (pairing, channel, sharing) = Self.started(as: .player)
        channel.receive(.received(Partner.choosing(.manager)))
        sharing.hold()
        channel.receive(.received(sharing.url.absoluteString))
        #expect(await eventually { sharing.isHeld })

        // When
        pairing.reset()
        sharing.release()

        // Then
        #expect(await eventually { sharing.cancelledAccepts == 1 })
    }
}

// MARK: - Private

private extension NearbyPairingTests {
    static func pairing(
        sharing: FakeSharing,
        failures: RecordedFailures = .init(),
        channels: FakeChannels
    ) -> NearbyPairing {
        NearbyPairing(
            sharing: sharing,
            failures: failures,
            makeChannel: { channels.make() },
            partnerJoinCheckInterval: .milliseconds(1)
        )
    }

    /// 相手とつながったところまで進める。
    static func started(
        as role: Role,
        failures: RecordedFailures = .init(),
        sharing: FakeSharing = .init()
    ) -> (NearbyPairing, FakeChannel, FakeSharing) {
        let channels = FakeChannels()
        let pairing = pairing(sharing: sharing, failures: failures, channels: channels)
        pairing.start(as: role)
        let channel = channels.made[0]
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

/// 開き直すたびに、新しい通信路を作る。
private final class FakeChannels {
    private(set) var made: [FakeChannel] = []

    func make() -> FakeChannel {
        let channel = FakeChannel()
        made.append(channel)
        return channel
    }
}

private final class FakeChannel: NearbyChannel {
    let events: AsyncStream<NearbyEvent>
    private(set) var sent: [String] = []

    private let continuation: AsyncStream<NearbyEvent>.Continuation
    private var isDisconnected = false

    init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    func receive(_ event: NearbyEvent) {
        if case .disconnected = event {
            isDisconnected = true
        }
        continuation.yield(event)
    }

    func start() {}

    func stop() {
        continuation.finish()
    }

    func send(_ text: String) throws(PairingFailure) {
        guard !isDisconnected else { throw .disconnected }
        sent.append(text)
    }
}

/// 共有を作るのと参加するのを止めておける。その途中でやめたり、通信が切れたりした状況を作るために使う。
@MainActor
private final class FakeSharing: PartnershipSharing {
    nonisolated let url = URL(fileURLWithPath: "/share")
    var failure: PairingFailure?
    var partnerJoined = true
    private(set) var makeShareCalls = 0
    private(set) var returnedCount = 0
    private(set) var cancelledAccepts = 0

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
        return (url, StubShare(isOwner: true, partnerJoined: partnerJoined))
    }

    func acceptShare(from url: URL) async throws(PairingFailure) -> any PairedShare {
        if held {
            await withCheckedContinuation { waiting = $0 }
        }
        if Task.isCancelled {
            cancelledAccepts += 1
        }
        return StubShare(isOwner: false)
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
