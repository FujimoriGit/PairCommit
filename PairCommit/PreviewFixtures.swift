//
//  PreviewFixtures.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Application
import Domain
import Foundation

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
        doneCriteria: String = "体重68kg以下、次回の健康診断で全項目A判定",
        status: Status,
        deadline: Date? = nil,
        why: String? = nil,
        createdAt: Date = .preview
    ) -> Self {
        .init(
            id: id,
            statement: statement,
            doneCriteria: doneCriteria,
            deadline: deadline,
            why: why,
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
            synchronizer: PreviewSynchronizer(),
            state: PartnershipState(
                pairing: Pairing(id: UUID(), ownerRole: role, createdAt: Date()),
                visions: visions,
                tasks: tasks
            )
        )
    }
}

struct PreviewSynchronizer: PartnershipSyncing {
    func start() -> PartnershipState {
        .init()
    }

    func load() -> PartnershipState {
        .init()
    }

    func save(_ state: PartnershipState, replacing base: PartnershipState) {}
}

struct PreviewNudgeNotifications: NudgeNotifying {
    func requestPermission() async {}

    func replace(with notices: [NudgeNotice], now: Date) async {}

    func withdrawAll() async {}
}

struct PreviewSharing: PartnershipSharing {
    func makeShare(initialState: PartnershipState) async throws(PairingFailure) -> (url: URL, share: any PairedShare) {
        throw .unexpected
    }

    func acceptShare(from url: URL) async throws(PairingFailure) -> any PairedShare {
        throw .unexpected
    }

    func savedShare() -> (any PairedShare)? {
        nil
    }

    func clearSavedShare() {}
}

struct PreviewInviting: PartnershipInviting {
    func send() async throws(PairingFailure) -> URL {
        throw .unexpected
    }

    func advance(ownerRole: Role) async throws(PairingFailure) -> InvitationProgress {
        throw .unexpected
    }

    func withdraw() async throws(PairingFailure) {}

    func join(_ link: URL) async throws(PairingFailure) {
        throw .unexpected
    }

    func advanceJoining() async throws(PairingFailure) -> (any PairedShare)? {
        throw .unexpected
    }

    func leave() async throws(PairingFailure) {}

    func endPair() async throws(PairingFailure) {}

    func savedStage() -> InvitationStage? {
        nil
    }

    func savedWithdrawal() -> Withdrawal? {
        nil
    }

    func save(_ stage: InvitationStage) {}

    func save(_ withdrawal: Withdrawal) {}

    func clearSaved() {}
}

final class PreviewNearbyChannel: NearbyChannel {
    let events = AsyncStream<NearbyEvent> { $0.finish() }

    func start() {}

    func stop() {}

    func send(_ text: String) throws(PairingFailure) {}
}

struct PreviewCriteriaReview: CriteriaReviewing {
    func review(statement: String, doneCriteria: String) async throws(ReviewFailure) -> CriteriaReview {
        .init(isVerifiable: true, advice: "数値と期日が入っているので判定できます")
    }
}
