//
//  PartnershipStoreTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Application
import Domain
import Foundation
import Testing

@MainActor
struct PartnershipStoreTests {

    @Test("操作は保存の完了を待たずに手元の状態に反映され、保存もされる")
    func anActionAppliesLocallyRightAwayAndIsSaved() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(
            role: .player,
            synchronizer: synchronizer,
            state: .init(),
            failures: RecordedFailures(),
            announcement: .quiet
        )

        // When
        try await store.perform { state, role throws(VisionDraftingError) in
            try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
        }

        // Then
        #expect(store.state.visions.count == 1)
        let saved = await synchronizer.load()
        #expect(saved == store.state)
    }

    @Test("役割やルールで許されない操作は、状態を変えずにエラーになる")
    func aForbiddenActionChangesNothing() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: .init(),
            failures: RecordedFailures(),
            announcement: .quiet
        )

        // When / Then
        await #expect(throws: PartnershipFailure<VisionDraftingError>.rejected(.notPlayer)) {
            try await store.perform { state, role throws(VisionDraftingError) in
                try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
            }
        }
        #expect(store.state == PartnershipState())
    }

    @Test("相手の操作は、最新の状態を取得すると手元の状態に反映される")
    func partnersChangeAppearsAfterReloading() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(
            role: .player,
            synchronizer: synchronizer,
            state: .init(),
            failures: RecordedFailures(),
            announcement: .quiet
        )
        let remote = try PartnershipState().establishingPairing(ownerRole: .player)
        try await synchronizer.save(remote, replacing: .init())

        // When
        try await store.refresh()

        // Then
        #expect(store.state == remote)
    }

    @Test("自分の操作の保存中に最新の状態を取得しても、自分の操作は消えない")
    func reloadingWhileSavingKeepsTheSavedAction() async throws {
        // Given
        let synchronizer = InterruptibleSynchronizer()
        let store = PartnershipStore(
            role: .player,
            synchronizer: synchronizer,
            state: .init(),
            failures: RecordedFailures(),
            announcement: .quiet
        )
        synchronizer.hold()

        // When
        let performing = Task {
            try await store.perform { state, role throws(VisionDraftingError) in
                try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
            }
        }
        await Task.yield()
        let refreshing = Task { try await store.refresh() }
        await Task.yield()
        synchronizer.release()
        try await performing.value
        try await refreshing.value

        // Then
        #expect(store.state.visions.count == 1)
    }

    @Test("続けて操作して保存が重なっても、どちらの操作も消えない")
    func overlappingActionsAreBothKept() async throws {
        // Given
        let synchronizer = InterruptibleSynchronizer()
        let store = PartnershipStore(
            role: .player,
            synchronizer: synchronizer,
            state: .init(),
            failures: RecordedFailures(),
            announcement: .quiet
        )
        synchronizer.hold()

        // When
        let first = Task {
            try await store.perform { state, role throws(VisionDraftingError) in
                try state.draftingVision(.init(statement: "s1", doneCriteria: "c1", deadline: nil, why: nil), by: role).state
            }
        }
        await Task.yield()
        let second = Task {
            try await store.perform { state, role throws(VisionDraftingError) in
                try state.draftingVision(.init(statement: "s2", doneCriteria: "c2", deadline: nil, why: nil), by: role).state
            }
        }
        await Task.yield()
        synchronizer.release()
        try await first.value
        try await second.value

        // Then
        #expect(store.state.visions.count == 2)
        #expect(synchronizer.stored == store.state)
    }

    @Test("保存に失敗した操作は、手元の状態からも取り消され、エラーになる")
    func anActionThatFailsToSaveIsUndone() async throws {
        // Given
        let synchronizer = InterruptibleSynchronizer()
        synchronizer.failure = .unavailable
        let store = PartnershipStore(
            role: .player,
            synchronizer: synchronizer,
            state: .init(),
            failures: RecordedFailures(),
            announcement: .quiet
        )

        // When / Then
        await #expect(throws: PartnershipFailure<VisionDraftingError>.notSynchronized(.unavailable)) {
            try await store.perform { state, role throws(VisionDraftingError) in
                try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
            }
        }
        #expect(store.state == PartnershipState())
    }

    @Test("保存の結果を待たない操作が保存に失敗したら、エラーにはならず、手元の状態から取り消されて保存の失敗が残る")
    func anActionNotAwaitingItsSaveIsUndoneAndItsFailureKept() async {
        // Given
        let synchronizer = InterruptibleSynchronizer()
        synchronizer.failure = .unavailable
        let store = PartnershipStore(
            role: .player,
            synchronizer: synchronizer,
            state: .init(),
            failures: RecordedFailures(),
            announcement: .quiet
        )

        // When
        await store.send { state, role throws(VisionDraftingError) in
            try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
        }

        // Then
        #expect(store.state == PartnershipState())
        #expect(store.saveFailure == .unavailable)
    }

    @Test("保存の結果を待たない操作が、相手の先の操作で成り立たなくなったら、エラーにはならず、相手の操作を手元の状態に反映して競合の失敗が残る")
    func anActionNotAwaitingItsSaveKeepsAConflictWhenThePartnerClosedItFirst() async throws {
        // Given
        let (shared, taskID) = try Self.reportedTask()
        let synchronizer = InMemorySynchronizer(initialState: shared)
        let first = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: shared,
            failures: RecordedFailures(),
            announcement: .quiet
        )
        let second = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: shared,
            failures: RecordedFailures(),
            announcement: .quiet
        )
        try await first.perform { state, role throws(TaskApprovalError) in
            try state.approvingTask(taskID, by: role)
        }

        // When
        await second.send { state, role throws(TaskCancellationError) in
            try state.cancellingTask(taskID, by: role)
        }

        // Then
        #expect(second.state == first.state)
        #expect(second.saveFailure == .outdated(latest: first.state))
    }

    @Test("相手の操作を取得する前に自分が操作しても、相手の操作は消えずに両方残る")
    func actingBeforeReloadingKeepsThePartnersChange() async throws {
        // Given
        let (shared, taskID) = try Self.reportedTask()
        let synchronizer = InMemorySynchronizer(initialState: shared)
        let player = PartnershipStore(
            role: .player,
            synchronizer: synchronizer,
            state: shared,
            failures: RecordedFailures(),
            announcement: .quiet
        )
        let manager = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: shared,
            failures: RecordedFailures(),
            announcement: .quiet
        )
        try await player.perform { state, role throws(ReactionError) in
            try state.settingReaction(.happy, on: taskID, by: role)
        }

        // When
        try await manager.perform { state, role throws(TaskApprovalError) in
            try state.approvingTask(taskID, by: role)
        }

        // Then
        let saved = await synchronizer.load()
        let task = try #require(saved.tasks.first { $0.id == taskID })
        #expect(task.reaction == .happy)
        #expect(task.status == .approved)
        #expect(manager.state == saved)
    }

    @Test("相手の操作が先に保存されて自分の操作が成り立たなくなったら、相手の操作を手元の状態に反映し、エラーになる")
    func actionMadeImpossibleByThePartnerFailsAndShowsTheirChange() async throws {
        // Given
        let (shared, taskID) = try Self.reportedTask()
        let synchronizer = InMemorySynchronizer(initialState: shared)
        let first = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: shared,
            failures: RecordedFailures(),
            announcement: .quiet
        )
        let second = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: shared,
            failures: RecordedFailures(),
            announcement: .quiet
        )
        try await first.perform { state, role throws(TaskApprovalError) in
            try state.approvingTask(taskID, by: role)
        }

        // When / Then
        await #expect(throws: PartnershipFailure<TaskCancellationError>.rejected(.alreadyClosed)) {
            try await second.perform { state, role throws(TaskCancellationError) in
                try state.cancellingTask(taskID, by: role)
            }
        }
        #expect(second.state == first.state)
    }

    @Test("相手の保存と競合し続けたら、再試行をやめ、相手の操作を手元の状態に反映し、競合のエラーになる")
    func actionGivesUpWhenThePartnerKeepsSavingFirst() async throws {
        // Given
        let latest = try PartnershipState().establishingPairing(ownerRole: .manager)
        let synchronizer = InterruptibleSynchronizer()
        synchronizer.failure = .outdated(latest: latest)
        let store = PartnershipStore(
            role: .player,
            synchronizer: synchronizer,
            state: .init(),
            failures: RecordedFailures(),
            announcement: .quiet
        )

        // When / Then
        await #expect(throws: PartnershipFailure<VisionDraftingError>.notSynchronized(.outdated(latest: latest))) {
            try await store.perform { state, role throws(VisionDraftingError) in
                try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
            }
        }
        #expect(store.state == latest)
    }

    @Test("見届ける人のビジョンの承認が保存できずに取り消されても、挑む人がビジョンを提出したとは知らされない")
    func managerIsNotToldOfASubmissionWhenTheirApprovalIsUndone() async throws {
        // Given
        let proposed = try Self.proposedVision()
        let synchronizer = InterruptibleSynchronizer()
        synchronizer.stored = proposed.state
        synchronizer.failure = .unavailable
        let notifications = RecordingPartnerActions()
        let store = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: proposed.state,
            failures: RecordedFailures(),
            announcement: .recording(into: notifications, known: proposed.state)
        )

        // When
        _ = await store.send { state, role throws(VisionApprovalError) in
            try state.approvingVision(proposed.visionID, by: role)
        }

        // Then
        #expect(notifications.notices.isEmpty)
    }

    @Test("挑む人の完了報告を取り直す前に見届ける人が操作すると、見届ける人に完了報告が知らされる")
    func managerActingBeforeFetchingTheReportIsToldOfIt() async throws {
        // Given
        let (reported, taskID) = try Self.reportedTask()
        let before = try reported.returningTask(taskID, feedback: "f", by: .manager)
        let synchronizer = InMemorySynchronizer(initialState: before)
        try await synchronizer.save(try before.reportingTask(taskID, by: .player), replacing: before)
        let notifications = RecordingPartnerActions()
        let store = PartnershipStore(
            role: .manager,
            synchronizer: synchronizer,
            state: before,
            failures: RecordedFailures(),
            announcement: .recording(into: notifications, known: before)
        )

        // When
        try await store.perform { state, role throws(TaskCreationError) in
            try state.creatingTask(title: "u", by: role).state
        }

        // Then
        #expect(notifications.notices == [PartnerActionNotice(action: .taskReported(taskID), message: "操作")])
    }

    @Test("役割やルールで許されない操作を断られると、断られた理由が診断の記録に残る")
    func aForbiddenActionIsRecorded() async {
        // Given
        let failures = RecordedFailures()
        let store = PartnershipStore(
            role: .manager,
            synchronizer: InMemorySynchronizer(),
            state: .init(),
            failures: failures,
            announcement: .quiet
        )

        // When
        _ = await store.send { state, role throws(VisionDraftingError) in
            try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
        }

        // Then
        #expect(failures.recorded.contains { $0 as? PartnershipFailure<VisionDraftingError> == .rejected(.notPlayer) })
    }

    @Test("保存できなかった操作は、保存できなかったことが診断の記録に残る")
    func anActionThatFailsToSaveIsRecorded() async {
        // Given
        let synchronizer = InterruptibleSynchronizer()
        synchronizer.failure = .unavailable
        let failures = RecordedFailures()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init(), failures: failures, announcement: .quiet)

        // When
        _ = await store.send { state, role throws(VisionDraftingError) in
            try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
        }

        // Then
        #expect(failures.recorded.contains {
            $0 as? PartnershipFailure<VisionDraftingError> == .notSynchronized(.unavailable)
        })
    }

    @Test("ペアリングが完了したら、保存されたペアの状態から使い始める")
    func usageStartsWithTheSavedPair() async throws {
        // Given
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
        let share = StubShare(isOwner: false, synchronizer: InMemorySynchronizer(initialState: paired))

        // When
        let store = try await PartnershipStore(starting: share, failures: RecordedFailures(), announcement: .quiet)

        // Then
        #expect(store?.state == paired)
    }

    @Test("ペアを保存した側は、自分が選んだ役割で使い始める", arguments: Role.allCases)
    func savingSideStartsWithTheRoleItChose(chosen: Role) async throws {
        // Given
        let paired = try PartnershipState().establishingPairing(ownerRole: chosen)
        let share = StubShare(isOwner: true, synchronizer: InMemorySynchronizer(initialState: paired))

        // When
        let store = try await PartnershipStore(starting: share, failures: RecordedFailures(), announcement: .quiet)

        // Then
        #expect(store?.role == chosen)
    }

    @Test("ペアに参加した側は、保存した側が選ばなかった役割で使い始める", arguments: Role.allCases)
    func joiningSideStartsWithTheRoleTheOtherDidNotChoose(chosen: Role) async throws {
        // Given
        let paired = try PartnershipState().establishingPairing(ownerRole: chosen)
        let share = StubShare(isOwner: false, synchronizer: InMemorySynchronizer(initialState: paired))

        // When
        let store = try await PartnershipStore(starting: share, failures: RecordedFailures(), announcement: .quiet)

        // Then
        let role = try #require(store?.role)
        #expect(role != chosen)
    }

    @Test("受け取ったデータにペアがなければ、使い始めない")
    func nothingStartsWithoutAPair() async throws {
        // Given
        let share = StubShare(isOwner: true, synchronizer: InMemorySynchronizer())

        // When
        let store = try await PartnershipStore(starting: share, failures: RecordedFailures(), announcement: .quiet)

        // Then
        #expect(store == nil)
    }
}

// MARK: - Private

private extension PartnershipStoreTests {
    static func proposedVision() throws -> (state: PartnershipState, visionID: Vision.ID) {
        try PartnershipState()
            .establishingPairing(ownerRole: .manager)
            .submittingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player)
    }

    static func reportedTask() throws -> (state: PartnershipState, taskID: TaskItem.ID) {
        let drafted = try PartnershipState()
            .establishingPairing(ownerRole: .manager)
            .draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player)
        let active = try drafted.state
            .proposingVision(drafted.visionID, by: .player)
            .approvingVision(drafted.visionID, by: .manager)
        let created = try active.creatingTask(title: "t", by: .manager)
        return (try created.state.reportingTask(created.taskID, by: .player), created.taskID)
    }
}

/// 保存を止めておける同期層。保存が重なった状況を作るために使う。
@MainActor
private final class InterruptibleSynchronizer: PartnershipSyncing {
    var stored: PartnershipState = .init()
    var failure: SyncFailure?

    private var held = false
    private var waiting: CheckedContinuation<Void, Never>?

    func hold() {
        held = true
    }

    func release() {
        held = false
        waiting?.resume()
        waiting = nil
    }

    func start() -> PartnershipState {
        stored
    }

    func load() -> PartnershipState {
        stored
    }

    func save(_ state: PartnershipState, replacing base: PartnershipState) async throws(SyncFailure) {
        if held {
            await withCheckedContinuation { waiting = $0 }
        }
        if let failure {
            throw failure
        }
        guard stored == base else { throw .outdated(latest: stored) }
        stored = state
    }
}
