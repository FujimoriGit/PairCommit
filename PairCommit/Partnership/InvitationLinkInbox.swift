//
//  InvitationLinkInbox.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Observation

/// 開かれた招待リンクを、画面が受け取るまで預かる。
// 受け取れるのは UIKit が生成するシーンのデリゲートだけで、そこには画面の状態を渡せない。
@MainActor
@Observable
final class InvitationLinkInbox {
    static let shared = InvitationLinkInbox()

    var received: (any InvitationLink)?
}
