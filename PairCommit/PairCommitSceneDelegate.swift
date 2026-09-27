//
//  PairCommitSceneDelegate.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import CloudKit
import UIKit

// SwiftUI の App には、招待リンクを開いたときの参加の情報を受け取る口がない。
@MainActor
final class PairCommitSceneDelegate: NSObject, UIWindowSceneDelegate {
    // 起動していなかったときは、こちらで渡される。
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let metadata = connectionOptions.cloudKitShareMetadata else { return }
        InvitationLinkInbox.shared.received = CloudKitInvitationLink(metadata: metadata)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        InvitationLinkInbox.shared.received = CloudKitInvitationLink(metadata: cloudKitShareMetadata)
    }
}
