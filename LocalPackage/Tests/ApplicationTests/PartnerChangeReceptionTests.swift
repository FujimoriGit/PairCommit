//
//  PartnerChangeReceptionTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import Foundation
import Testing

@MainActor
struct PartnerChangeReceptionTests {

    @Test("アプリを開いているかにかかわらず、挑む人が完了を報告すると、見届ける人に完了報告が知らされる", arguments: [false, true])
    func reportIsToldToTheManager(isActive: Bool) async throws {
        // Given
        let (before, taskID) = try Self.pairedWithTask()
        let synchronizer = InMemorySynchronizer(initialState: before)
        let notifications = RecordingPartnerActions()
        let session = PartnershipSession.make(
            saved: StubShare(isOwner: true, synchronizer: synchronizer),
            announcement: .recording(into: notifications, known: before)
        )
        await session.connect()
        try await synchronizer.save(try before.reportingTask(taskID, by: .player), replacing: before)

        // When
        _ = try await Self.reception().receive(in: session, isActive: isActive)

        // Then
        #expect(notifications.notices == [PartnerActionNotice(action: .taskReported(taskID), message: "操作")])
    }

    @Test("アプリが終了したあとに起こされても、相手の操作が知らされる")
    func actionIsToldAfterTheAppWasTerminated() async throws {
        // Given
        let (before, taskID) = try Self.pairedWithTask()
        let synchronizer = InMemorySynchronizer(initialState: before)
        try await synchronizer.save(try before.reportingTask(taskID, by: .player), replacing: before)
        let notifications = RecordingPartnerActions()
        let session = PartnershipSession.make(
            saved: StubShare(isOwner: true, synchronizer: synchronizer),
            announcement: .recording(into: notifications, known: before)
        )

        // When
        _ = try await Self.reception().receive(in: session, isActive: false)

        // Then
        #expect(notifications.notices == [PartnerActionNotice(action: .taskReported(taskID), message: "操作")])
    }

    @Test("相手の変更の知らせが続けて届いても、同じ操作は1度しか知らされない")
    func consecutiveArrivalsTellTheActionOnce() async throws {
        // Given
        let (before, taskID) = try Self.pairedWithTask()
        let synchronizer = InMemorySynchronizer(initialState: before)
        let notifications = RecordingPartnerActions()
        let session = PartnershipSession.make(
            saved: StubShare(isOwner: true, synchronizer: synchronizer),
            announcement: .recording(into: notifications, known: before)
        )
        await session.connect()
        try await synchronizer.save(try before.reportingTask(taskID, by: .player), replacing: before)
        let reception = Self.reception()

        // When
        async let first = reception.receive(in: session, isActive: false)
        async let second = reception.receive(in: session, isActive: false)
        _ = try await (first, second)

        // Then
        #expect(notifications.notices == [PartnerActionNotice(action: .taskReported(taskID), message: "操作")])
    }

    @Test("相手の変更の知らせで起こされてつないでいる間にアプリを開くと、次の知らせが届いても、挑む人の完了報告は見届ける人に1度だけ知らされる")
    func openingTheAppWhileWokenTellsTheReportOnce() async throws {
        // Given
        let (before, taskID) = try Self.pairedWithTask()
        let synchronizer = LateFirstStart(stale: before, latest: try before.reportingTask(taskID, by: .player))
        let notifications = RecordingPartnerActions()
        let session = PartnershipSession.make(
            saved: StubShare(isOwner: true, synchronizer: synchronizer),
            announcement: .recording(into: notifications, known: before)
        )
        let reception = Self.reception()
        let woken = Task { try await reception.receive(in: session, isActive: false) }
        await synchronizer.waitForFirstStart()
        await session.connect()
        await synchronizer.release()
        _ = try await woken.value

        // When
        _ = try await reception.receive(in: session, isActive: false)

        // Then
        #expect(notifications.notices == [PartnerActionNotice(action: .taskReported(taskID), message: "操作")])
    }
}

// MARK: - Private

private extension PartnerChangeReceptionTests {
    static func pairedWithTask() throws -> (state: PartnershipState, taskID: TaskItem.ID) {
        let drafted = try PartnershipState()
            .establishingPairing(ownerRole: .manager)
            .draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player)
        return try drafted.state
            .proposingVision(drafted.visionID, by: .player)
            .approvingVision(drafted.visionID, by: .manager)
            .creatingTask(title: "t", by: .manager)
    }

    static func reception() -> PartnerChangeReception {
        .init(nudges: SilentNudges(), nudgeMessage: { _, _ in "催促" })
    }
}

/// 最初の取得は `release()` まで返らず、返すのはそれより前の `stale` の状態。
private actor LateFirstStart: PartnershipSyncing {
    private let stale: PartnershipState
    private let stored: InMemorySynchronizer
    private var hasStarted = false
    private var arrival: CheckedContinuation<Void, Never>?
    private var held: CheckedContinuation<Void, Never>?

    init(stale: PartnershipState, latest: PartnershipState) {
        self.stale = stale
        stored = InMemorySynchronizer(initialState: latest)
    }

    func start() async -> PartnershipState {
        guard !hasStarted else { return await stored.start() }
        hasStarted = true
        arrival?.resume()
        arrival = nil
        await withCheckedContinuation { held = $0 }
        return stale
    }

    func load() async -> PartnershipState {
        await stored.load()
    }

    func save(_ state: PartnershipState, replacing base: PartnershipState) async throws(SyncFailure) {
        try await stored.save(state, replacing: base)
    }

    func waitForFirstStart() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { arrival = $0 }
    }

    func release() {
        held?.resume()
        held = nil
    }
}
