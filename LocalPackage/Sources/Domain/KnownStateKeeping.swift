//
//  KnownStateKeeping.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Foundation

/// この端末が最後に受け取った状態を、アプリが終了しても残す。相手の操作のうち、まだ知らせていないものを決めるのに使う。
public protocol KnownStateKeeping: Sendable {
    func lastKnown() -> PartnershipState?
    func keep(_ state: PartnershipState)
    func forget()
}
