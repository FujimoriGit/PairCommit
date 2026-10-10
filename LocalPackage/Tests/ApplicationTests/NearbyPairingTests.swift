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

    @Test("2台とも同じ役割を選ぶと、ペアは登録されず、役割が重なったと出る", arguments: Role.allCases)
    func choosingTheSameRoleOnBothDevicesRegistersNoPair(chosen: Role) async {
        // Given
        let (pairing, channel, sharing) = Self.started(with: .role(chosen))

        // When
        channel.receive(.received(Partner.choosing(.role(chosen))))

        // Then
        #expect(await eventually { pairing.phase == .failed(.sameRole(chosen)) })
        #expect(sharing.makeShareCalls == 0)
    }

    @Test("自分の iCloud がいっぱいでも、相手の iCloud にペアを登録して、ペアリングを終えられる")
    func pairingFinishesInThePartnersICloudWhenYoursIsFull() async {
        // Given
        let (pairing, channel, sharing) = Self.started(with: .role(.manager))
        sharing.failure = .storageFull
        channel.receive(.received(Partner.choosing(.invitation)))
        #expect(await eventually { channel.sent.contains(Partner.handingOver(.manager)) })

        // When
        channel.receive(.received(Partner.registeredPair))

        // Then
        #expect(await eventually { pairing.phase == .done })
        #expect(pairing.outcome?.isOwner == false)
    }

    @Test("自分の iCloud にペアを登録したら、相手が参加し終えたところで、ペアリングできたと出る")
    func pairingFinishesOnceThePartnerHasJoined() async {
        // Given
        let (pairing, channel, sharing) = Self.started(with: .role(.manager))
        channel.receive(.received(Partner.choosing(.invitation)))
        #expect(await eventually { channel.sent.contains(sharing.url.absoluteString) })

        // When
        channel.receive(.received(Partner.acknowledgement))

        // Then
        #expect(await eventually { pairing.phase == .done })
        #expect(pairing.outcome?.isOwner == true)
    }

    @Test("ペアを登録している途中でやめたら、ペアは残らず、相手にも届かない")
    func cancellingWhileRegisteringThePairLeavesNoPair() async {
        // Given
        let (pairing, channel, sharing) = Self.started(with: .role(.manager))
        sharing.hold()
        channel.receive(.received(Partner.choosing(.invitation)))
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
    static func started(with choice: PairingChoice) -> (NearbyPairing, FakeChannel, FakeSharing) {
        let channel = FakeChannel()
        let sharing = FakeSharing()
        let pairing = NearbyPairing(sharing: sharing, makeChannel: { channel })
        pairing.start(with: choice)
        channel.receive(.connected)
        return (pairing, channel, sharing)
    }
}

/// 相手の端末が送ってくる文字列。
private enum Partner {
    static let acknowledgement = "paircommit://ack"
    static let registeredPair = "file:///partners-pair"

    static func choosing(_ choice: PairingChoice) -> String {
        switch choice {
        case .role(let role): "paircommit://choice/\(role.rawValue)"
        case .invitation: "paircommit://choice/invitation"
        }
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
