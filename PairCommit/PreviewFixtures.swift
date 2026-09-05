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

// プレビューが「いま」とみなす瞬間。期限も状態の変更時刻もここからの相対で置く。
// 実時間を使うと、期限を過ぎた日から催促が出はじめて基準画像が壊れる。
extension Date {
    static let preview = Date(timeIntervalSince1970: 1_800_000_000)

    static func preview(daysLater days: Int) -> Self {
        preview.addingTimeInterval(Double(days) * 24 * 60 * 60)
    }
}

extension Vision {
    static func preview(
        id: UUID = UUID(),
        statement: String = "半年で10kg痩せて健康診断オールA",
        status: Status,
        deadline: Date? = nil,
        createdAt: Date = .preview
    ) -> Self {
        .init(
            id: id,
            statement: statement,
            doneCriteria: "体重68kg以下、次回の健康診断で全項目A判定",
            deadline: deadline,
            why: nil,
            status: status,
            createdAt: createdAt
        )
    }
}

extension TaskItem {
    static func preview(
        visionID: Vision.ID,
        title: String,
        status: Status,
        createdBy: Role = .player,
        reaction: Reaction? = nil,
        deadline: Date? = nil,
        statusChangedAt: Date = .preview
    ) -> Self {
        .init(
            id: UUID(),
            visionID: visionID,
            title: title,
            status: status,
            createdBy: createdBy,
            reaction: reaction,
            deadline: deadline,
            createdAt: Date(),
            statusChangedAt: statusChangedAt
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

struct PreviewCriteriaReview: CriteriaReviewing {
    func review(statement: String, doneCriteria: String) async throws(ReviewFailure) -> CriteriaReview {
        .init(isVerifiable: true, advice: "数値と期日が入っているので判定できます")
    }
}
