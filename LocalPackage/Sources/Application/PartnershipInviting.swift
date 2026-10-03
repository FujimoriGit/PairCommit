//
//  PartnershipInviting.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Domain
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

    func savedStep() -> InvitationStep?
    func savedWithdrawal() -> Withdrawal?
    /// 送る途中と参加する途中は残らない。
    func save(_ step: InvitationStep)
    func save(_ withdrawal: Withdrawal)
    func clearSaved()
}

public enum InvitationProgress: Sendable {
    case waiting(URL)
    case paired(any PairedShare)
}

/// 離れた相手とのペアリングの途中。
public enum InvitationStep: Equatable, Sendable {
    case sending(ownerRole: Role)
    case sent(ownerRole: Role)
    case accepting(URL)
    case joined
}

/// やめる後始末で片付けるもの。
public enum Withdrawal: Equatable, Sendable {
    case invitation
    case membership
    case pair
}
