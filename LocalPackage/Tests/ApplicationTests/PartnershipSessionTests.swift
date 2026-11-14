//
//  PartnershipSessionTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/12
//

import Application
import Domain
import Foundation
import Testing

@MainActor
struct PartnershipSessionTests {

    @Test("前のペアが端末に残っていれば、つなぐと、そのペアの役割で使い始める")
    func thePairLeftOnTheDeviceStartsWithItsRole() async throws {
        let session = try PartnershipSession.make(saved: Self.share())

        await session.connect()

        #expect(session.store?.role == .manager)
    }

    @Test("前のペアが相手の側で終わっていたら、つなぐと、ペアが終わったことを伝えて役割の選択に戻る")
    func anEndedPairLeftOnTheDeviceReturnsToTheRolePicker() async {
        let session = PartnershipSession.make(saved: StubShare(isOwner: true))

        await session.connect()

        #expect(session.stage == .choosingRole(.partnershipEnded))
    }

    @Test("前のペアにつなげなかったら、つなげなかった理由を出して、つなぎ直しを待つ")
    func failingToConnectWaitsForRetry() async {
        let session = PartnershipSession.make(saved: UnreachableShare())

        await session.connect()

        #expect(session.stage == .connecting(.unavailable))
    }

    @Test("端末の外に前のペアが残っていれば、つなぐと、そのペアの役割で使い始める")
    func aRemainingPairStartsWithItsRole() async throws {
        let session = try PartnershipSession.make(remaining: Self.share())
        await session.resumeRemainingPairing()

        await session.connect()

        #expect(session.store?.role == .manager)
    }

    @Test("役割を選んでペアの組み方を選んでいる間は、端末の外に前のペアが残っていても、そのペアにつながない")
    func choosingHowToPairIsNotInterruptedByARemainingPair() async throws {
        let session = try PartnershipSession.make(remaining: Self.share())
        session.chosenRole = .manager

        await session.resumeRemainingPairing()

        #expect(session.stage == .choosingRole(nil))
    }

    @Test("ペアを組んでいるときに招待リンクを開くと、組み済みとして断る")
    func invitationLinkIsRefusedWhilePaired() async throws {
        let session = try PartnershipSession.make(saved: Self.share())
        await session.connect()

        #expect(throws: PartnershipSession.LinkRefusal.alreadyPaired) {
            try session.accept(Self.link)
        }
    }

    @Test("近くの相手とペアリングしている途中に招待リンクを開くと、ペアリング中として断る")
    func invitationLinkIsRefusedWhilePairingNearby() {
        let session = PartnershipSession.make()
        session.pairNearby(as: .manager)

        #expect(throws: PartnershipSession.LinkRefusal.pairingInProgress) {
            try session.accept(Self.link)
        }
    }

    @Test("相手がペアを終えたら、ペアが終わったことを伝えて役割の選択に戻る")
    func partnerEndingThePairReturnsToTheRolePicker() async throws {
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
        let synchronizer = InMemorySynchronizer(initialState: paired)
        let session = PartnershipSession.make(saved: StubShare(isOwner: true, synchronizer: synchronizer))
        await session.connect()
        try await synchronizer.save(.init(), replacing: paired)
        try await session.store?.refresh()

        await session.followStateChange()

        #expect(session.stage == .choosingRole(.partnershipEnded))
    }

    @Test("ペアリングをやり直すと、役割の選択に戻る")
    func redoingThePairingReturnsToTheRolePicker() async throws {
        let session = try PartnershipSession.make(saved: Self.share())
        await session.connect()

        try await session.endPartnership()

        #expect(session.stage == .choosingRole(nil))
    }

    @Test("ペアリングをやり直すと、いまのペアも、前に組んで残っていたペアも終わる")
    func redoingThePairingEndsEveryRemainingPair() async throws {
        let pairs = RemainingPairs(["いまのペア", "前のペア"])
        let session = try PartnershipSession.make(saved: Self.share("いまのペア", in: pairs))
        await session.connect()

        try await session.endPartnership()

        #expect(await pairs.names.isEmpty)
    }

    @Test("招待リンクで新しくペアを組むと、前に組んで残っていたペアが終わる")
    func pairingAnewEndsThePairsLeftBefore() async throws {
        let pairs = RemainingPairs(["新しいペア", "前のペア"])
        let session = try PartnershipSession.make(joined: Self.share("新しいペア", in: pairs))
        try session.accept(Self.link)
        await session.pairRemotely()

        await session.connect()

        #expect(await pairs.names == ["新しいペア"])
    }

    @Test("前に組んで残っていたペアを終わらせられなくても、招待リンクで組んだペアを使い始める")
    func pairingAnewStartsEvenIfThePairsLeftBeforeCannotBeEnded() async throws {
        let pairs = RemainingPairs(["新しいペア", "前のペア"])
        let session = try PartnershipSession.make(joined: Self.leftoverKeepingShare("新しいペア", in: pairs))
        try session.accept(Self.link)
        await session.pairRemotely()

        await session.connect()

        #expect(session.store?.role == .manager)
    }

    @Test("前に組んで残っていたペアを終わらせられないと、その理由が診断の記録に残る")
    func failingToEndThePairsLeftBeforeIsRecorded() async throws {
        let pairs = RemainingPairs(["新しいペア", "前のペア"])
        let failures = RecordedFailures()
        let session = try PartnershipSession.make(joined: Self.leftoverKeepingShare("新しいペア", in: pairs), failures: failures)
        try session.accept(Self.link)
        await session.pairRemotely()

        await session.connect()

        #expect(failures.recorded.contains { $0 as? PairingFailure == .offline })
    }

    @Test("前に組んで残っていたペアを終わらせられないと、ペアリングをやり直してもエラーになり、いまのペアは相手の側でも続く")
    func redoingThePairingKeepsTheCurrentPairIfThePairsLeftBeforeCannotBeEnded() async throws {
        let pairs = RemainingPairs(["いまのペア", "前のペア"])
        let session = try PartnershipSession.make(saved: Self.leftoverKeepingShare("いまのペア", in: pairs))
        await session.connect()

        await #expect(throws: PairingFailure.offline) {
            try await session.endPartnership()
        }

        #expect(await pairs.names.contains("いまのペア"))
    }

    @Test("端末の外に残っていたペアにつなぎ直しても、ほかに残っていたペアは終わらない")
    func resumingARemainingPairKeepsTheOthers() async throws {
        let pairs = RemainingPairs(["つなぎ直したペア", "ほかのペア"])
        let session = try PartnershipSession.make(remaining: Self.share("つなぎ直したペア", in: pairs))
        await session.resumeRemainingPairing()

        await session.connect()

        #expect(await pairs.names == ["つなぎ直したペア", "ほかのペア"])
    }
}

// MARK: - Private

private extension PartnershipSessionTests {
    static let link = URL(fileURLWithPath: "/invitation")

    static func share() throws -> StubShare {
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
        return StubShare(isOwner: true, synchronizer: InMemorySynchronizer(initialState: paired))
    }

    static func leftoverKeepingShare(_ name: String, in pairs: RemainingPairs) throws -> LeftoverKeepingShare {
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
        return LeftoverKeepingShare(name: name, pairs: pairs, stored: InMemorySynchronizer(initialState: paired))
    }

    static func share(_ name: String, in pairs: RemainingPairs) throws -> RemainingPairShare {
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
        return RemainingPairShare(name: name, pairs: pairs, stored: InMemorySynchronizer(initialState: paired))
    }
}

private struct UnreachableShare: PairedShare {
    let isOwner = true

    func synchronizer() -> any PartnershipSyncing {
        UnreachableSynchronizer()
    }

    func save() {}

    func hasPartnerJoined() async throws(PairingFailure) -> Bool {
        true
    }

    func end() async throws(PairingFailure) {}

    func endOtherPairs() async throws(PairingFailure) {}
}

private actor RemainingPairs {
    private(set) var names: Set<String>

    init(_ names: Set<String>) {
        self.names = names
    }

    func end(_ name: String) {
        names.remove(name)
    }

    func end(allBut name: String) {
        names = names.filter { $0 == name }
    }
}

private struct RemainingPairShare: PairedShare {
    let name: String
    let pairs: RemainingPairs
    let stored: InMemorySynchronizer
    let isOwner = true

    func synchronizer() -> any PartnershipSyncing {
        stored
    }

    func save() {}

    func hasPartnerJoined() async throws(PairingFailure) -> Bool {
        true
    }

    func end() async throws(PairingFailure) {
        await pairs.end(name)
    }

    func endOtherPairs() async throws(PairingFailure) {
        await pairs.end(allBut: name)
    }
}

private struct LeftoverKeepingShare: PairedShare {
    let name: String
    let pairs: RemainingPairs
    let stored: InMemorySynchronizer
    let isOwner = true

    func synchronizer() -> any PartnershipSyncing {
        stored
    }

    func save() {}

    func hasPartnerJoined() async throws(PairingFailure) -> Bool {
        true
    }

    func end() async throws(PairingFailure) {
        await pairs.end(name)
    }

    func endOtherPairs() async throws(PairingFailure) {
        throw .offline
    }
}

private struct UnreachableSynchronizer: PartnershipSyncing {
    func start() throws(SyncFailure) -> PartnershipState {
        throw .unavailable
    }

    func load() throws(SyncFailure) -> PartnershipState {
        throw .unavailable
    }

    func save(_ state: PartnershipState, replacing base: PartnershipState) throws(SyncFailure) {
        throw .unavailable
    }
}
