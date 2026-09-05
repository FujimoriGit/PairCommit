//
//  PartnershipSession.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/05
//

import Application
import Observation

/// ペアが成立してからの状態。プッシュで起こされたときに画面の更新を待たずに触れるよう、アプリ側で持つ。
@MainActor
@Observable
final class PartnershipSession {
    var store: PartnershipStore?
}
