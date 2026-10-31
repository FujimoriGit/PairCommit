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
        // Given
        let session = try Self.session(saved: Self.share())

        // When
        await session.connect()

        // Then
        #expect(session.store?.role == .manager)
    }

    @Test("前のペアが相手の側で終わっていたら、つなぐと、ペアが終わったことを伝えて役割の選択に戻る")
    func anEndedPairLeftOnTheDeviceReturnsToTheRolePicker() async {
        // Given
        let session = Self.session(saved: StubShare(isOwner: true))

        // When
        await session.connect()

        // Then
        #expect(session.stage == .choosingRole(.partnershipEnded))
    }

    @Test("前のペアにつなげなかったら、つなげなかった理由を出して、つなぎ直しを待つ")
    func failingToConnectWaitsForRetry() async {
        // Given
        let session = Self.session(saved: UnreachableShare())

        // When
        await session.connect()

        // Then
        #expect(session.stage == .connecting(.unavailable))
    }

    @Test("端末の外に前のペアが残っていれば、つなぐと、そのペアの役割で使い始める")
    func aRemainingPairStartsWithItsRole() async throws {
        // Given
        let session = try Self.session(remaining: Self.share())
        await session.resumeRemainingPairing()

        // When
        await session.connect()

        // Then
        #expect(session.store?.role == .manager)
    }

    @Test("役割を選んでペアの組み方を選んでいる間は、端末の外に前のペアが残っていても、そのペアにつながない")
    func choosingHowToPairIsNotInterruptedByARemainingPair() async throws {
        // Given
        let session = try Self.session(remaining: Self.share())
        session.chosenRole = .manager

        // When
        await session.resumeRemainingPairing()

        // Then
        #expect(session.stage == .choosingRole(nil))
    }

    @Test("ペアを組んでいるときに招待リンクを開くと、組み済みとして断る")
    func invitationLinkIsRefusedWhilePaired() async throws {
        // Given
        let session = try Self.session(saved: Self.share())
        await session.connect()

        // When / Then
        #expect(throws: PartnershipSession.LinkRefusal.alreadyPaired) {
            try session.accept(Self.link)
        }
    }

    @Test("近くの相手とペアリングしている途中に招待リンクを開くと、ペアリング中として断る")
    func invitationLinkIsRefusedWhilePairingNearby() {
        // Given
        let session = Self.session()
        session.pairNearby(as: .manager)

        // When / Then
        #expect(throws: PartnershipSession.LinkRefusal.pairingInProgress) {
            try session.accept(Self.link)
        }
    }

    @Test("相手がペアを終えたら、ペアが終わったことを伝えて役割の選択に戻る")
    func partnerEndingThePairReturnsToTheRolePicker() async throws {
        // Given
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
        let synchronizer = InMemorySynchronizer(initialState: paired)
        let session = Self.session(saved: StubShare(isOwner: true, synchronizer: synchronizer))
        await session.connect()
        try await synchronizer.save(.init(), replacing: paired)
        try await session.store?.refresh()

        // When
        await session.followStateChange()

        // Then
        #expect(session.stage == .choosingRole(.partnershipEnded))
    }

    @Test("ペアリングをやり直すと、役割の選択に戻る")
    func redoingThePairingReturnsToTheRolePicker() async throws {
        // Given
        let session = try Self.session(saved: Self.share())
        await session.connect()

        // When
        try await session.endPartnership()

        // Then
        #expect(session.stage == .choosingRole(nil))
    }

    @Test("ペアリングをやり直すと、いまのペアも、前に組んで残っていたペアも終わる")
    func redoingThePairingEndsEveryRemainingPair() async throws {
        // Given
        let pairs = RemainingPairs(["いまのペア", "前のペア"])
        let session = try Self.session(saved: Self.share("いまのペア", in: pairs))
        await session.connect()

        // When
        try await session.endPartnership()

        // Then
        #expect(await pairs.names.isEmpty)
    }

    @Test("招待リンクで新しくペアを組むと、前に組んで残っていたペアが終わる")
    func pairingAnewEndsThePairsLeftBefore() async throws {
        // Given
        let pairs = RemainingPairs(["新しいペア", "前のペア"])
        let session = try Self.session(joined: Self.share("新しいペア", in: pairs))
        try session.accept(Self.link)
        await session.pairRemotely()

        // When
        await session.connect()

        // Then
        #expect(await pairs.names == ["新しいペア"])
    }

    @Test("前に組んで残っていたペアを終わらせられなくても、招待リンクで組んだペアを使い始める")
    func pairingAnewStartsEvenIfThePairsLeftBeforeCannotBeEnded() async throws {
        // Given
        let pairs = RemainingPairs(["新しいペア", "前のペア"])
        let session = try Self.session(joined: Self.leftoverKeepingShare("新しいペア", in: pairs))
        try session.accept(Self.link)
        await session.pairRemotely()

        // When
        await session.connect()

        // Then
        #expect(session.store?.role == .manager)
    }

    @Test("前に組んで残っていたペアを終わらせられないと、その理由が診断の記録に残る")
    func failingToEndThePairsLeftBeforeIsRecorded() async throws {
        // Given
        let pairs = RemainingPairs(["新しいペア", "前のペア"])
        let failures = RecordedFailures()
        let session = try Self.session(joined: Self.leftoverKeepingShare("新しいペア", in: pairs), failures: failures)
        try session.accept(Self.link)
        await session.pairRemotely()

        // When
        await session.connect()

        // Then
        #expect(failures.recorded.contains { $0 as? PairingFailure == .offline })
    }

    @Test("前に組んで残っていたペアを終わらせられないと、ペアリングをやり直してもエラーになり、いまのペアは相手の側でも続く")
    func redoingThePairingKeepsTheCurrentPairIfThePairsLeftBeforeCannotBeEnded() async throws {
        // Given
        let pairs = RemainingPairs(["いまのペア", "前のペア"])
        let session = try Self.session(saved: Self.leftoverKeepingShare("いまのペア", in: pairs))
        await session.connect()

        // When
        await #expect(throws: PairingFailure.offline) {
            try await session.endPartnership()
        }

        // Then
        #expect(await pairs.names.contains("いまのペア"))
    }

    @Test("端末の外に残っていたペアにつなぎ直しても、ほかに残っていたペアは終わらない")
    func resumingARemainingPairKeepsTheOthers() async throws {
        // Given
        let pairs = RemainingPairs(["つなぎ直したペア", "ほかのペア"])
        let session = try Self.session(remaining: Self.share("つなぎ直したペア", in: pairs))
        await session.resumeRemainingPairing()

        // When
        await session.connect()

        // Then
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

    static func session(
        saved: (any PairedShare)? = nil,
        remaining: (any PairedShare)? = nil,
        joined: (any PairedShare)? = nil,
        failures: RecordedFailures = .init()
    ) -> PartnershipSession {
        .init(
            sharing: StubSharing(saved: saved, remaining: remaining),
            inviting: IdleInviting(joined: joined),
            nudges: SilentNudges(),
            announcement: .quiet,
            failures: failures,
            nudgeMessage: { _, _ in "" },
            makeNearbyChannel: { SilentChannel() }
        )
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

private struct StubSharing: PartnershipSharing {
    let saved: (any PairedShare)?
    let remaining: (any PairedShare)?

    func makeShare(initialState: PartnershipState) async throws(PairingFailure) -> (url: URL, share: any PairedShare) {
        throw .unexpected
    }

    func acceptShare(from url: URL) async throws(PairingFailure) -> any PairedShare {
        throw .unexpected
    }

    func savedShare() -> (any PairedShare)? {
        saved
    }

    func remainingShare() async throws(PairingFailure) -> (any PairedShare)? {
        remaining
    }

    func declineRemainingShare() {}

    func clearSavedShare() {}
}

private struct IdleInviting: PartnershipInviting {
    let joined: (any PairedShare)?

    func send() async throws(PairingFailure) -> URL {
        throw .unexpected
    }

    func advance(ownerRole: Role) async throws(PairingFailure) -> InvitationProgress {
        throw .unexpected
    }

    func withdraw() async throws(PairingFailure) {}

    func join(_ link: URL) async throws(PairingFailure) {
        guard joined != nil else { throw .unexpected }
    }

    func advanceJoining() async throws(PairingFailure) -> (any PairedShare)? {
        guard let joined else { throw .unexpected }
        return joined
    }

    func leave() async throws(PairingFailure) {}

    func endPair() async throws(PairingFailure) {}

    func savedStage() -> InvitationStage? {
        nil
    }

    func savedWithdrawal() -> Withdrawal? {
        nil
    }

    func save(_ stage: InvitationStage) {}

    func save(_ withdrawal: Withdrawal) {}

    func clearSaved() {}
}

private struct SilentNudges: NudgeNotifying {
    func requestPermission() async {}

    func replace(with notices: [NudgeNotice], now: Date) async {}

    func withdrawAll() async {}
}

private final class SilentChannel: NearbyChannel {
    let events = AsyncStream<NearbyEvent> { $0.finish() }

    func start() {}

    func stop() {}

    func send(_ text: String) throws(PairingFailure) {}
}
