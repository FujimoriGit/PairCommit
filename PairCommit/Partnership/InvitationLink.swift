//
//  InvitationLink.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

/// 開かれた招待リンク。
protocol InvitationLink: Sendable {
    /// - Returns: 参加した招待。
    func join() async throws -> RemoteRecordID
}
