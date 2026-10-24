//
//  FailureRecording.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/24
//

/// 利用者の操作や手順が失敗したことを、開発者があとから読めるところに残す。
public protocol FailureRecording: Sendable {
    /// - Parameter operation: 失敗した操作。開発者がどこで起きたかを辿れる名前にする。
    func record(_ failure: any Error, during operation: String)
}
