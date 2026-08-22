//
//  PreviewFixtures.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Application
import Domain
import Foundation
import Infrastructure

extension Vision {
    static func preview(id: UUID = UUID(), status: Status) -> Self {
        .init(
            id: id,
            statement: "半年で10kg痩せて健康診断オールA",
            doneCriteria: "体重68kg以下、次回の健康診断で全項目A判定",
            deadline: nil,
            why: nil,
            status: status,
            createdAt: Date()
        )
    }
}

extension TaskItem {
    static func preview(
        visionID: Vision.ID,
        title: String,
        status: Status,
        createdBy: Role = .player,
        reaction: Reaction? = nil
    ) -> Self {
        .init(
            id: UUID(),
            visionID: visionID,
            title: title,
            status: status,
            createdBy: createdBy,
            reaction: reaction,
            deadline: nil,
            createdAt: Date()
        )
    }
}

extension PartnershipStore {
    static func preview(role: Role, visions: [Vision], tasks: [TaskItem] = []) -> Self {
        .init(
            role: role,
            synchronizer: InMemorySynchronizer(),
            state: PartnershipState(
                pairing: Pairing(id: UUID(), ownerRole: role, createdAt: Date()),
                visions: visions,
                tasks: tasks
            )
        )
    }
}
