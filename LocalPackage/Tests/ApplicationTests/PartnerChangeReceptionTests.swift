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

    @Test("アプリを開いていない間に挑む人が完了を報告すると、見届ける人に完了報告が知らされる")
    func reportWhileInBackgroundIsToldToTheManager() async throws {
        // Given
        let (before, taskID) = try Self.pairedWithTask()
        let synchronizer = InMemorySynchronizer(initialState: before)
        let store = PartnershipStore(role: .manager, synchronizer: synchronizer, state: before)
        try await synchronizer.save(try before.reportingTask(taskID, by: .player), replacing: before)
        let notifications = RecordingPartnerActions()
        let reception = Self.reception(known: before, notifying: notifications)

        // When
        _ = try await reception.receive(into: store, orStartingFrom: nil, isActive: false)

        // Then
        #expect(notifications.notices == [PartnerActionNotice(action: .taskReported(taskID), message: "操作")])
    }

    @Test("アプリを開いている間に届いた相手の操作は、通知されない")
    func actionWhileInForegroundIsNotNotified() async throws {
        // Given
        let (before, taskID) = try Self.pairedWithTask()
        let synchronizer = InMemorySynchronizer(initialState: before)
        let store = PartnershipStore(role: .manager, synchronizer: synchronizer, state: before)
        try await synchronizer.save(try before.reportingTask(taskID, by: .player), replacing: before)
        let notifications = RecordingPartnerActions()
        let reception = Self.reception(known: before, notifying: notifications)

        // When
        _ = try await reception.receive(into: store, orStartingFrom: nil, isActive: true)

        // Then
        #expect(notifications.notices.isEmpty)
    }

    @Test("アプリが終了したあとに起こされても、相手の操作が知らされる")
    func actionIsToldAfterTheAppWasTerminated() async throws {
        // Given
        let (before, taskID) = try Self.pairedWithTask()
        let synchronizer = InMemorySynchronizer(initialState: before)
        try await synchronizer.save(try before.reportingTask(taskID, by: .player), replacing: before)
        let notifications = RecordingPartnerActions()
        let reception = Self.reception(known: before, notifying: notifications)

        // When
        _ = try await reception.receive(
            into: nil,
            orStartingFrom: StubShare(isOwner: true, synchronizer: synchronizer),
            isActive: false
        )

        // Then
        #expect(notifications.notices == [PartnerActionNotice(action: .taskReported(taskID), message: "操作")])
    }

    @Test("相手の変更の知らせが続けて届いても、同じ操作は1度しか知らされない")
    func consecutiveArrivalsTellTheActionOnce() async throws {
        // Given
        let (before, taskID) = try Self.pairedWithTask()
        let synchronizer = InMemorySynchronizer(initialState: before)
        let store = PartnershipStore(role: .manager, synchronizer: synchronizer, state: before)
        try await synchronizer.save(try before.reportingTask(taskID, by: .player), replacing: before)
        let notifications = RecordingPartnerActions()
        let reception = Self.reception(known: before, notifying: notifications)

        // When
        async let first = reception.receive(into: store, orStartingFrom: nil, isActive: false)
        async let second = reception.receive(into: store, orStartingFrom: nil, isActive: false)
        _ = try await (first, second)

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

    static func reception(known: PartnershipState, notifying notifications: RecordingPartnerActions) -> PartnerChangeReception {
        .init(
            knownState: MemoryKnownState(known),
            nudges: SilentNudges(),
            partnerActions: notifications,
            nudgeMessage: { _, _ in "催促" },
            partnerActionMessage: { _, _ in "操作" }
        )
    }
}

@MainActor
private final class RecordingPartnerActions: PartnerActionNotifying {
    private(set) var notices: [PartnerActionNotice] = []

    func deliver(_ notices: [PartnerActionNotice]) async {
        self.notices += notices
    }

    func withdrawAll() async {}
}

private final class MemoryKnownState: KnownStateKeeping, @unchecked Sendable {
    private let lock = NSLock()
    private var state: PartnershipState?

    init(_ state: PartnershipState?) {
        self.state = state
    }

    func lastKnown() -> PartnershipState? {
        lock.withLock { state }
    }

    func keep(_ state: PartnershipState) {
        lock.withLock { self.state = state }
    }

    func forget() {
        lock.withLock { state = nil }
    }
}

private struct SilentNudges: NudgeNotifying {
    func requestPermission() async {}

    func replace(with notices: [NudgeNotice], now: Date) async {}

    func withdrawAll() async {}
}
