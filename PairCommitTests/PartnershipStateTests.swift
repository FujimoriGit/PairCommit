//
//  PartnershipStateTests.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation
import Testing
@testable import PairCommit

/// ドメインの不変条件・ロールガード・状態遷移のテスト。
struct PartnershipStateTests {

    // MARK: - ペアリング

    @Test func ペアリングは一度しか確立できない() throws {
        var state = PartnershipState()
        try state.establishPairing(ownerRole: .manager)
        #expect(state.pairing?.ownerRole == .manager)
        #expect(throws: DomainError.alreadyPaired) {
            try state.establishPairing(ownerRole: .player)
        }
    }

    // MARK: - Vision ライフサイクル

    @Test func プレイヤーが起案し管理者が承認するとactiveになる() throws {
        var state = PartnershipState()
        let id = try state.draftVision(statement: "半年で10kg痩せる", doneCriteria: "健康診断オールA", by: .player)
        #expect(state.visions.first?.status == .draft)

        try state.proposeVision(id, by: .player)
        #expect(state.visions.first?.status == .proposed)

        try state.approveVision(id, by: .manager)
        #expect(state.activeVision?.id == id)
    }

    @Test func 管理者はビジョンを起案できない() {
        var state = PartnershipState()
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.draftVision(statement: "s", doneCriteria: "c", by: .manager)
        }
    }

    @Test func プレイヤーはビジョンを承認できない() throws {
        var state = PartnershipState()
        let id = try state.proposedVision()
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.approveVision(id, by: .player)
        }
    }

    @Test func activeなVisionは高々1個() throws {
        var state = PartnershipState()
        try state.makeActiveVision()
        let second = try state.proposedVision()
        #expect(throws: DomainError.activeVisionAlreadyExists) {
            try state.approveVision(second, by: .manager)
        }
    }

    @Test func 管理者は承認待ちビジョンをdraftに差し戻せる() throws {
        var state = PartnershipState()
        let id = try state.proposedVision()
        try state.rejectVision(id, by: .manager)
        #expect(state.visions.first?.status == .draft)
    }

    @Test func draftをいきなり承認はできない() throws {
        var state = PartnershipState()
        let id = try state.draftVision(statement: "s", doneCriteria: "c", by: .player)
        #expect(throws: DomainError.invalidVisionTransition(from: .draft)) {
            try state.approveVision(id, by: .manager)
        }
    }

    @Test func ビジョンを閉じると未完了タスクも一緒に閉じる() throws {
        var state = PartnershipState()
        let visionID = try state.makeActiveVision()

        let todo = try state.createTask(title: "todoのまま", by: .manager)
        let reported = try state.createTask(title: "報告済み", by: .manager)
        try state.reportTask(reported, by: .player)
        let proposed = try state.createTask(title: "プレイヤー起案", by: .player)
        let approved = try state.createTask(title: "承認済み", by: .manager)
        try state.reportTask(approved, by: .player)
        try state.approveTask(approved, by: .manager)

        try state.closeVision(visionID, as: .achieved, by: .manager)

        #expect(state.visions.first?.status == .achieved)
        #expect(state.status(of: todo) == .cancelled)
        #expect(state.status(of: reported) == .cancelled)
        #expect(state.status(of: proposed) == .cancelled)
        #expect(state.status(of: approved) == .approved)
        #expect(state.activeVision == nil)
    }

    @Test func プレイヤーはビジョンを閉じられない() throws {
        var state = PartnershipState()
        let visionID = try state.makeActiveVision()
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.closeVision(visionID, as: .abandoned, by: .player)
        }
    }

    @Test func 前のビジョンを閉じれば次を承認できる() throws {
        var state = PartnershipState()
        let first = try state.makeActiveVision()
        try state.closeVision(first, as: .abandoned, by: .manager)

        let second = try state.proposedVision()
        try state.approveVision(second, by: .manager)
        #expect(state.activeVision?.id == second)
    }

    // MARK: - タスクライフサイクル

    @Test func 管理者のタスクはtodoで始まりプレイヤー起案はproposedで始まる() throws {
        var state = PartnershipState()
        try state.makeActiveVision()

        let byManager = try state.createTask(title: "管理者生成", by: .manager)
        let byPlayer = try state.createTask(title: "プレイヤー起案", by: .player)

        #expect(state.status(of: byManager) == .todo)
        #expect(state.status(of: byPlayer) == .proposed)
    }

    @Test func タスクはactiveなVisionがないと作れない() {
        var state = PartnershipState()
        #expect(throws: DomainError.noActiveVision) {
            try state.createTask(title: "孤立タスク", by: .manager)
        }
    }

    @Test func 報告と承認のフロー() throws {
        var state = PartnershipState()
        try state.makeActiveVision()
        let id = try state.createTask(title: "t", by: .manager)

        try state.reportTask(id, by: .player)
        #expect(state.status(of: id) == .reported)

        try state.approveTask(id, by: .manager)
        #expect(state.status(of: id) == .approved)
    }

    @Test func プレイヤーは承認できず管理者は報告できない() throws {
        var state = PartnershipState()
        try state.makeActiveVision()
        let id = try state.createTask(title: "t", by: .manager)

        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.reportTask(id, by: .manager)
        }
        try state.reportTask(id, by: .player)
        #expect(throws: DomainError.roleForbidden(required: .manager)) {
            try state.approveTask(id, by: .player)
        }
    }

    @Test func 管理者はプレイヤー起案を採用できる() throws {
        var state = PartnershipState()
        try state.makeActiveVision()
        let id = try state.createTask(title: "起案", by: .player)

        try state.adoptTask(id, by: .manager)
        #expect(state.status(of: id) == .todo)
    }

    @Test func 管理者は報告を差し戻せる() throws {
        var state = PartnershipState()
        try state.makeActiveVision()
        let id = try state.createTask(title: "t", by: .manager)
        try state.reportTask(id, by: .player)

        try state.returnTask(id, by: .manager)
        #expect(state.status(of: id) == .todo)
    }

    @Test func 管理者は未完了タスクを取り下げられるが完了タスクは取り下げられない() throws {
        var state = PartnershipState()
        try state.makeActiveVision()
        let open = try state.createTask(title: "未完了", by: .manager)
        let done = try state.createTask(title: "完了", by: .manager)
        try state.reportTask(done, by: .player)
        try state.approveTask(done, by: .manager)

        try state.cancelTask(open, by: .manager)
        #expect(state.status(of: open) == .cancelled)

        #expect(throws: DomainError.invalidTaskTransition(from: .approved)) {
            try state.cancelTask(done, by: .manager)
        }
    }

    @Test func todoのまま承認はできない() throws {
        var state = PartnershipState()
        try state.makeActiveVision()
        let id = try state.createTask(title: "t", by: .manager)
        #expect(throws: DomainError.invalidTaskTransition(from: .todo)) {
            try state.approveTask(id, by: .manager)
        }
    }

    // MARK: - 感情リアクション

    @Test func プレイヤーは感情を上書きで表明できる() throws {
        var state = PartnershipState()
        try state.makeActiveVision()
        let id = try state.createTask(title: "t", by: .manager)

        try state.setReaction(.uneasy, on: id, by: .player)
        #expect(state.tasks.first?.reaction == .uneasy)

        try state.setReaction(.happy, on: id, by: .player)
        #expect(state.tasks.first?.reaction == .happy)

        try state.setReaction(nil, on: id, by: .player)
        #expect(state.tasks.first?.reaction == nil)
    }

    @Test func 管理者は感情を表明できない() throws {
        var state = PartnershipState()
        try state.makeActiveVision()
        let id = try state.createTask(title: "t", by: .manager)
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.setReaction(.angry, on: id, by: .manager)
        }
    }
}

// MARK: - テストヘルパー

private extension PartnershipState {
    /// draft → proposed まで進めた Vision を作る。
    mutating func proposedVision() throws -> Vision.ID {
        let id = try draftVision(statement: "statement", doneCriteria: "criteria", by: .player)
        try proposeVision(id, by: .player)
        return id
    }

    /// active な Vision を1つ用意する。
    @discardableResult
    mutating func makeActiveVision() throws -> Vision.ID {
        let id = try proposedVision()
        try approveVision(id, by: .manager)
        return id
    }

    func status(of taskID: TaskItem.ID) -> TaskItem.Status? {
        tasks.first { $0.id == taskID }?.status
    }
}
