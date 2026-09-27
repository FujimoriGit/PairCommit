//
//  PartnershipInviting.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import Foundation

/// 離れた相手と、招待リンクでペアを作る。
protocol PartnershipInviting: Sendable {
    /// - Returns: 相手に送る招待リンク。
    func send() async throws -> URL
    /// 相手の参加を確かめて、ペアの成立へ進める。
    func advance(ownerRole: Role) async throws -> InvitationProgress
    func withdraw() async throws
    /// 招待した側がペアを用意していたら参加する。
    /// - Returns: 成立したペア。まだ用意されていなければ nil。
    func advanceJoining(_ invitationID: RemoteRecordID) async throws -> PairingOutcome?
    /// 招待と、参加済みならペアからも抜ける。
    func leave(_ invitationID: RemoteRecordID) async throws
}
