//
//  PartnershipStateFixtures.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/26
//

import Domain
import Foundation

extension PartnershipState {
    func proposedVision() throws -> (state: PartnershipState, visionID: Vision.ID) {
        let (drafted, visionID) = try draftingVision(
            .init(statement: "statement", doneCriteria: "criteria", deadline: nil, why: nil), by: .player
        )
        return (try drafted.proposingVision(visionID, by: .player), visionID)
    }

    func activeVision() throws -> (state: PartnershipState, visionID: Vision.ID) {
        let (proposed, visionID) = try proposedVision()
        return (try proposed.approvingVision(visionID, by: .manager), visionID)
    }

    func activeVisionWithTask(title: String = "t") throws -> (state: PartnershipState, taskID: TaskItem.ID) {
        let (active, _) = try activeVision()
        return try active.creatingTask(title: title, by: .manager)
    }

    func closedVision(statement: String, as outcome: Vision.Outcome, now: Date) throws -> Self {
        let (drafted, visionID) = try draftingVision(
            .init(statement: statement, doneCriteria: "criteria", deadline: nil, why: nil), by: .player, now: now
        )
        return try drafted
            .proposingVision(visionID, by: .player)
            .approvingVision(visionID, by: .manager)
            .closingVision(visionID, as: outcome, by: .manager)
    }

    func status(of taskID: TaskItem.ID) -> TaskItem.Status? {
        tasks.first { $0.id == taskID }?.status
    }
}
