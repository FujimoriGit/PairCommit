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
        let announcement = PartnerActionAnnouncement.recording(into: notifications, known: before)
        let store = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: before,
            failures: RecordedFailures(),
            announcement: announcement
        )
        try await synchronizer.save(try before.reportingTask(taskID, by: .player), replacing: before)

        // When
        _ = try await Self.reception(announcing: announcement).receive(into: store, orStartingFrom: nil, isActive: isActive)

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
        let reception = Self.reception(announcing: .recording(into: notifications, known: before))

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
        let notifications = RecordingPartnerActions()
        let announcement = PartnerActionAnnouncement.recording(into: notifications, known: before)
        let store = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: before,
            failures: RecordedFailures(),
            announcement: announcement
        )
        try await synchronizer.save(try before.reportingTask(taskID, by: .player), replacing: before)
        let reception = Self.reception(announcing: announcement)

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

    static func reception(announcing announcement: PartnerActionAnnouncement) -> PartnerChangeReception {
        .init(
            nudges: SilentNudges(),
            announcement: announcement,
            nudgeMessage: { _, _ in "催促" },
            failures: RecordedFailures()
        )
    }
}

private struct SilentNudges: NudgeNotifying {
    func requestPermission() async {}

    func replace(with notices: [NudgeNotice], now: Date) async {}

    func withdrawAll() async {}
}
