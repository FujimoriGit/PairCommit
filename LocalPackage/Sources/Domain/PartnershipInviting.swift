//
//  PartnershipInviting.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Foundation

/// 離れた相手と、招待リンクでペアを作る。
public protocol PartnershipInviting: Sendable {
    /// - Returns: 相手に送る招待リンク。
    func send() async throws(PairingFailure) -> URL
    /// 相手が招待リンクで参加していたら、その相手だけが参加できるペアの共有を用意する。
    /// 相手がそちらにも参加していたら、招待リンクを消してペアの成立を返す。
    func advance(ownerRole: Role) async throws(PairingFailure) -> InvitationProgress
    /// 招待リンクと、そこから作ったペアを消す。
    func withdraw() async throws(PairingFailure)

    func join(_ link: URL) async throws(PairingFailure)
    /// 招待した側がペアの共有を用意していたら参加する。
    /// - Returns: 参加できたペア。まだ用意されていなければ nil。
    func advanceJoining() async throws(PairingFailure) -> (any PairedShare)?
    /// 招待リンクの共有と、参加済みならペアの共有からも抜ける。
    func leave() async throws(PairingFailure)
    /// 招待リンクで作ったペアを、相手の側でも終わらせる。
    func endPair() async throws(PairingFailure)

    func savedStage() -> InvitationStage?
    func savedWithdrawal() -> Withdrawal?
    func save(_ stage: InvitationStage)
    func save(_ withdrawal: Withdrawal)
    func clearSaved()
}

public enum InvitationProgress: Sendable {
    case waiting(URL)
    case paired(any PairedShare)
}

/// 開き直したときに戻る、離れた相手とのペアリングの段階。
public enum InvitationStage: Equatable, Sendable {
    case sent(ownerRole: Role)
    case joined
}

/// やめる後始末で片付けるもの。
public enum Withdrawal: Equatable, Sendable {
    case invitation
    case membership
    case pair
}
