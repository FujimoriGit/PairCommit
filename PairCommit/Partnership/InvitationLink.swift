//
//  InvitationLink.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import CloudKit

/// 招待リンクを開いたときに OS が渡してくる、参加するための情報。
struct InvitationLink: Equatable, Sendable {
    let metadata: CKShare.Metadata
}
