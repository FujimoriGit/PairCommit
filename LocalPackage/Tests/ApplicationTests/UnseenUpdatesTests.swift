//
//  UnseenUpdatesTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Application
import Domain
import Foundation
import Testing

@MainActor
struct UnseenUpdatesTests {

    @Test("見届ける人が取り直すと、挑む人の完了報告がまだ見ていない更新になり、アプリのアイコンに1が出る")
    func partnerReportBecomesAnUnseenUpdateOnTheIcon() async throws {
        let (before, taskID) = try Self.todoTask()
        let synchronizer = InMemorySynchronizer(initialState: try before.reportingTask(taskID, by: .player))
        let notifications = RecordingPartnerActions()
        let store = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: before,
            failures: RecordedFailures(),
            announcement: .recording(into: notifications, known: before)
        )

        try await store.refresh()

        #expect(store.unseen.count(on: .task(taskID)) == 1)
        #expect(notifications.badges.last == 1)
    }

    @Test("見届ける人が完了報告されたタスクを開くと、まだ見ていない更新から外れ、アプリのアイコンの数字が消える")
    func openingTheReportedTaskClearsTheIcon() async throws {
        let (before, taskID) = try Self.todoTask()
        let synchronizer = InMemorySynchronizer(initialState: try before.reportingTask(taskID, by: .player))
        let notifications = RecordingPartnerActions()
        let store = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: before,
            failures: RecordedFailures(),
            announcement: .recording(into: notifications, known: before)
        )
        try await store.refresh()

        await store.see([.task(taskID)])

        #expect(store.unseen.count(on: .task(taskID)) == 0)
        #expect(notifications.badges.last == 0)
    }
}

// MARK: - Private

private extension UnseenUpdatesTests {
    static func todoTask() throws -> (state: PartnershipState, taskID: TaskItem.ID) {
        let drafted = try PartnershipState()
            .establishingPairing(ownerRole: .manager)
            .draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player)
        let active = try drafted.state
            .proposingVision(drafted.visionID, by: .player)
            .approvingVision(drafted.visionID, by: .manager)
        return try active.creatingTask(title: "t", by: .manager)
    }
}
