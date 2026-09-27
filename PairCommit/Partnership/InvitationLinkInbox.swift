//
//  InvitationLinkInbox.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Observation

/// 招待リンクを開いたときに OS が渡してくる情報を、画面が受け取るまで預かる。
// 受け取れるのは UIKit が生成するシーンのデリゲートだけで、そこには画面の状態を渡せない。
@MainActor
@Observable
final class InvitationLinkInbox {
    static let shared = InvitationLinkInbox()

    var received: InvitationLink?
}
