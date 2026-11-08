//
//  PreviewFixtures.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/08
//

import Application
import Domain
import Foundation
import UIKit

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
        detail: String? = nil,
        status: Status,
        createdBy: Role = .player,
        reaction: Reaction? = nil,
        deadline: Date? = nil,
        statusChangedAt: Date = .preview,
        cancelledFrom: Status? = nil,
        progress: Int? = nil
    ) -> Self {
        .init(
            id: UUID(),
            visionID: visionID,
            title: title,
            detail: detail,
            status: status,
            createdBy: createdBy,
            reaction: reaction,
            deadline: deadline,
            createdAt: Date(),
            statusChangedAt: statusChangedAt,
            cancelledFrom: cancelledFrom,
            progress: progress
        )
    }
}

extension [TaskItem] {
    static func board(in vision: Vision) -> Self {
        [
            .preview(
                visionID: vision.id,
                title: "週3でジムに行く",
                status: .reported,
                reaction: .happy,
                deadline: .preview(daysLater: -5)
            ),
            .preview(visionID: vision.id, title: "毎朝体重を記録する", status: .proposed),
            .preview(
                visionID: vision.id,
                title: "夜10時以降は食べない",
                status: .todo,
                createdBy: .manager,
                reaction: .angry,
                deadline: .preview(daysLater: -3),
                progress: 40
            ),
            .preview(
                visionID: vision.id,
                title: "週末の献立を決める",
                status: .todo,
                createdBy: .manager,
                deadline: .preview.addingTimeInterval(3 * 60 * 60)
            ),
            .preview(
                visionID: vision.id,
                title: "間食をナッツに置き換える",
                status: .todo,
                reaction: .uneasy,
                deadline: .preview(daysLater: 3),
                progress: 70
            ),
            .preview(visionID: vision.id, title: "血液検査の予約を取る", status: .todo, createdBy: .manager, deadline: .preview(daysLater: 5)),
            .preview(visionID: vision.id, title: "5kmを30分で走る", status: .todo, deadline: .preview(daysLater: 23)),
            .preview(visionID: vision.id, title: "毎日8000歩あるく", status: .todo, createdBy: .manager, progress: 20),
            .preview(visionID: vision.id, title: "ジムに入会する", status: .approved, reaction: .happy, deadline: .preview(daysLater: -26)),
            .preview(visionID: vision.id, title: "体組成計を買う", status: .approved, createdBy: .manager, deadline: .preview(daysLater: -24)),
            .preview(visionID: vision.id, title: "間食をやめる", status: .cancelled)
        ]
    }
}

extension PartnershipStore {
    static func preview(
        role: Role,
        visions: [Vision],
        tasks: [TaskItem] = [],
        notes: [Note] = [],
        named: Bool = true
    ) -> Self {
        .init(
            role: role,
            synchronizer: PreviewSynchronizer(),
            state: PartnershipState(
                pairing: Pairing(
                    id: UUID(),
                    ownerRole: role,
                    createdAt: Date(),
                    managerName: named ? "太郎" : nil,
                    playerName: named ? "花子" : nil
                ),
                visions: visions,
                tasks: tasks,
                notes: notes,
                lastNoteNumber: notes.map(\.number).max() ?? 0
            ),
            failures: PreviewFailures(),
            announcement: .preview
        )
    }
}

extension PartnerActionAnnouncement {
    static var preview: Self {
        .init(knownState: PreviewKnownState(), notifying: PreviewPartnerActionNotifications(), message: { _, _ in "" })
    }
}

extension Note {
    static func previewSendingBack(_ vision: Vision) -> Self {
        .preview(
            on: .vision(vision.id),
            kind: .feedback(.returned),
            author: .manager,
            number: 1,
            body: "半年で10kgは急すぎる。月ごとの目安も書いてほしい"
        )
    }

    static func preview(on subject: Subject, kind: Kind, author: Role, number: Int, body: String) -> Self {
        .init(
            id: UUID(),
            subject: subject,
            kind: kind,
            author: author,
            number: number,
            body: body,
            writtenAt: .preview.addingTimeInterval(Double(number - 3) * 60 * 60)
        )
    }
}

extension PartnershipSession {
    static var preview: PartnershipSession {
        .init(
            sharing: PreviewSharing(),
            inviting: PreviewInviting(),
            nudges: PreviewNudgeNotifications(),
            announcement: .preview,
            failures: PreviewFailures(),
            nudgeMessage: { $0.message(in: $1) },
            makeNearbyChannel: { PreviewNearbyChannel() }
        )
    }
}

struct PreviewFailures: FailureRecording {
    func record(_ failure: any Error, during operation: String) {}
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

struct PreviewPartnerActionNotifications: PartnerActionNotifying {
    func deliver(_ notices: [PartnerActionNotice]) async {}

    func withdrawAll() async {}
}

struct PreviewKnownState: KnownStateKeeping {
    func lastKnown() -> PartnershipState? {
        nil
    }

    func keep(_ state: PartnershipState) {}

    func forget() {}
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

    func remainingShare() async throws(PairingFailure) -> (any PairedShare)? {
        nil
    }

    func declineRemainingShare() {}

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

// 読み込みを待たずに撮られるので、読み込めても基準画像には写らない。カードはカード単体のプレビューで写す。
struct OfflineLinkPreviews: LinkPreviewing {
    func preview(of url: URL) async throws(LinkPreviewFailure) -> LinkPreview {
        throw .failed
    }
}

extension LinkPreview {
    static let preview = LinkPreview(title: "初心者のための10kmランニング計画｜8週間で完走する練習メニュー", image: previewImage)
    static let previewWithoutImage = LinkPreview(title: "初心者のための10kmランニング計画｜8週間で完走する練習メニュー", image: nil)

    private static var previewImage: Data? {
        let size = CGSize(width: 382, height: 200)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [
                UIColor(red: 0.96, green: 0.64, blue: 0.38, alpha: 1).cgColor,
                UIColor(red: 0.16, green: 0.62, blue: 0.56, alpha: 1).cgColor
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: nil) else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        .pngData()
    }
}
