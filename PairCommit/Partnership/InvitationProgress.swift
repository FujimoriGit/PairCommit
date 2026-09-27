//
//  InvitationProgress.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Foundation

/// 招待した側から見た、相手の参加の進み具合。
enum InvitationProgress: Sendable {
    case waiting(URL)
    case paired(PairingOutcome)
}
