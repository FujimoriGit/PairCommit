//
//  InvitationInbox.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Foundation
import Observation

/// 招待リンクを開いたときに届いたリンクを、画面が受け取るまで預かる。
@MainActor
@Observable
public final class InvitationInbox {
    public var received: URL?

    public init() {}
}
