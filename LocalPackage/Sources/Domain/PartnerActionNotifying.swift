//
//  PartnerActionNotifying.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Foundation

/// 相手の操作を端末の通知として出す。
public protocol PartnerActionNotifying: Sendable {
    /// 同じ対象への同じ種類の操作の通知は、前に出したものを置き換える。感情はタスクごとに1件に置き換える。
    func deliver(_ notices: [PartnerActionNotice]) async
    func withdrawAll() async
}

public struct PartnerActionNotice: Hashable, Sendable {
    public let action: PartnerAction
    public let message: String

    public init(action: PartnerAction, message: String) {
        self.action = action
        self.message = message
    }
}
