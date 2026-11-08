//
//  UnseenKeeping.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Foundation

/// まだ見ていない相手の操作を、アプリが終了しても残す。
public protocol UnseenKeeping: Sendable {
    func lastUnseen() -> UnseenUpdates
    func keep(_ unseen: UnseenUpdates)
}
