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

    @Test("操作は iCloud への保存の完了を待たずに手元の状態に反映され、iCloud にも保存される")
    func anActionAppliesLocallyRightAwayAndIsSavedToICloud() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())

        // When
        try await store.perform { state, role throws(DomainError) in
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
        let store = PartnershipStore(role: .manager, synchronizer: synchronizer, state: .init())

        // When / Then
        await #expect(throws: PartnershipFailure.rejected(.roleForbidden(required: .player))) {
            try await store.perform { state, role throws(DomainError) in
                try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
            }
        }
        #expect(store.state == PartnershipState())
    }

    @Test("相手の操作は、最新の状態を取得すると手元の状態に反映される")
    func partnersChangeAppearsAfterReloading() async throws {
        // Given
        let synchronizer = InMemorySynchronizer()
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())
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
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())
        synchronizer.hold()

        // When
        let performing = Task {
            try await store.perform { state, role throws(DomainError) in
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
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())
        synchronizer.hold()

        // When
        let first = Task {
            try await store.perform { state, role throws(DomainError) in
                try state.draftingVision(.init(statement: "s1", doneCriteria: "c1", deadline: nil, why: nil), by: role).state
            }
        }
        await Task.yield()
        let second = Task {
            try await store.perform { state, role throws(DomainError) in
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

    @Test("iCloud への保存に失敗した操作は、手元の状態からも取り消され、エラーになる")
    func anActionThatFailsToSaveIsUndone() async throws {
        // Given
        let synchronizer = InterruptibleSynchronizer()
        synchronizer.failure = .unavailable
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())

        // When / Then
        await #expect(throws: PartnershipFailure.notSynchronized(.unavailable)) {
            try await store.perform { state, role throws(DomainError) in
                try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
            }
        }
        #expect(store.state == PartnershipState())
    }

    @Test("相手の操作を取得する前に自分が操作しても、相手の操作は消えずに両方残る")
    func actingBeforeReloadingKeepsThePartnersChange() async throws {
        // Given
        let (shared, taskID) = try Self.reportedTask()
        let synchronizer = InMemorySynchronizer(initialState: shared)
        let player = PartnershipStore(role: .player, synchronizer: synchronizer, state: shared)
        let manager = PartnershipStore(role: .manager, synchronizer: synchronizer, state: shared)
        try await player.perform { state, role throws(DomainError) in
            try state.settingReaction(.happy, on: taskID, by: role)
        }

        // When
        try await manager.perform { state, role throws(DomainError) in
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
        let first = PartnershipStore(role: .manager, synchronizer: synchronizer, state: shared)
        let second = PartnershipStore(role: .manager, synchronizer: synchronizer, state: shared)
        try await first.perform { state, role throws(DomainError) in
            try state.approvingTask(taskID, by: role)
        }

        // When / Then
        await #expect(throws: PartnershipFailure.rejected(.invalidTaskTransition(from: .approved))) {
            try await second.perform { state, role throws(DomainError) in
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
        let store = PartnershipStore(role: .player, synchronizer: synchronizer, state: .init())

        // When / Then
        await #expect(throws: PartnershipFailure.notSynchronized(.outdated(latest: latest))) {
            try await store.perform { state, role throws(DomainError) in
                try state.draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: role).state
            }
        }
        #expect(store.state == latest)
    }

    @Test("ペアリングが完了したら、iCloud に保存されたペアの状態から使い始める")
    func usageStartsWithThePairSavedInICloud() async throws {
        // Given
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
        let share = StubShare(isOwner: false, synchronizer: InMemorySynchronizer(initialState: paired))

        // When
        let store = try await PartnershipStore(starting: share)

        // Then
        #expect(store?.state == paired)
    }

    @Test("ペアを保存した側は、自分が選んだ役割で使い始める", arguments: Role.allCases)
    func savingSideStartsWithTheRoleItChose(chosen: Role) async throws {
        // Given
        let paired = try PartnershipState().establishingPairing(ownerRole: chosen)
        let share = StubShare(isOwner: true, synchronizer: InMemorySynchronizer(initialState: paired))

        // When
        let store = try await PartnershipStore(starting: share)

        // Then
        #expect(store?.role == chosen)
    }

    @Test("ペアに参加した側は、保存した側が選ばなかった役割で使い始める", arguments: Role.allCases)
    func joiningSideStartsWithTheRoleTheOtherDidNotChoose(chosen: Role) async throws {
        // Given
        let paired = try PartnershipState().establishingPairing(ownerRole: chosen)
        let share = StubShare(isOwner: false, synchronizer: InMemorySynchronizer(initialState: paired))

        // When
        let store = try await PartnershipStore(starting: share)

        // Then
        let role = try #require(store?.role)
        #expect(role != chosen)
    }

    @Test("iCloud から受け取ったデータにペアがなければ、使い始めない")
    func nothingStartsWithoutAPair() async throws {
        // Given
        let share = StubShare(isOwner: true, synchronizer: InMemorySynchronizer())

        // When
        let store = try await PartnershipStore(starting: share)

        // Then
        #expect(store == nil)
    }
}

// MARK: - Private

private extension PartnershipStoreTests {
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
