//
//  NudgeNotifying.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Foundation

/// 催促を端末の通知として出す。
public protocol NudgeNotifying: Sendable {
    func requestPermission() async
    /// 催促の通知を `notices` に揃える。`notices` にない催促の通知は取り下げる。
    func replace(with notices: [NudgeNotice], now: Date) async
    func withdrawAll() async
}

public struct NudgeNotice: Hashable, Sendable {
    public let nudge: Nudge
    public let message: String
    /// 通知を出す時刻。nil ならすぐ出す。
    public let startsAt: Date?

    public init(nudge: Nudge, message: String, startsAt: Date?) {
        self.nudge = nudge
        self.message = message
        self.startsAt = startsAt
    }
}
