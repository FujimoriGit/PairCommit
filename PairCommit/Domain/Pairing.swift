//
//  Pairing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Foundation

/// 2人を束ねる。必ず manager 1 + player 1 のちょうど2人で、ロールは固定。
/// 参加者の同一性は同期層（CloudKit なら CKShare の owner / participant）が担うため、
/// ドメインは「オーナー側がどちらのロールを取ったか」だけを持てば各端末の自ロールが定まる。
struct Pairing: Identifiable, Sendable, Codable, Equatable {
    let id: UUID
    /// 共有のオーナー側（CKShare を作った側）が取ったロール。相手側は自動的にもう一方。
    let ownerRole: Role
    let createdAt: Date
}
