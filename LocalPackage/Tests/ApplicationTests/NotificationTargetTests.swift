//
//  NotificationTargetTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Application
import Domain
import Foundation
import Testing

struct NotificationTargetTests {

    @Test("タスクの通知を押すと、そのタスクの詳細が開く")
    func taskNotificationOpensTheTask() throws {
        let (active, _) = try Self.activeVision()
        let (state, taskID) = try active.creatingTask(title: "走る", by: .manager)

        let target = state.target(of: .task(taskID))

        #expect(target == .detail(.task(taskID)))
    }

    @Test("進行中のビジョンの通知を押すと、そのビジョンの詳細が開く")
    func activeVisionNotificationOpensTheVision() throws {
        let (state, visionID) = try Self.activeVision()

        let target = state.target(of: .vision(visionID))

        #expect(target == .detail(.activeVision(visionID)))
    }

    @Test("閉じたビジョンの通知を押すと、記録のそのビジョンが開く")
    func closedVisionNotificationOpensTheRecord() throws {
        let (active, visionID) = try Self.activeVision()
        let state = try active.closingVision(visionID, as: .achieved, by: .manager)

        let target = state.target(of: .vision(visionID))

        #expect(target == .detail(.closedVision(visionID)))
    }

    @Test("提出されたビジョンの通知を押すと、ホームが開く")
    func proposedVisionNotificationOpensHome() throws {
        let (state, visionID) = try Self.proposedVision()

        let target = state.target(of: .vision(visionID))

        #expect(target == .home)
    }

    @Test("見つからないタスクの通知を押しても、何も開かない")
    func notificationForAMissingTaskOpensNothing() throws {
        let (state, _) = try Self.activeVision()

        let target = state.target(of: .task(UUID()))

        #expect(target == nil)
    }
}

// MARK: - Private

private extension NotificationTargetTests {
    static func proposedVision() throws -> (state: PartnershipState, visionID: Vision.ID) {
        let drafted = try PartnershipState()
            .establishingPairing(ownerRole: .manager)
            .draftingVision(.init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player)
        return (try drafted.state.proposingVision(drafted.visionID, by: .player), drafted.visionID)
    }

    static func activeVision() throws -> (state: PartnershipState, visionID: Vision.ID) {
        let (proposed, visionID) = try proposedVision()
        return (try proposed.approvingVision(visionID, by: .manager), visionID)
    }
}
