//
//  InvitationSceneDelegate.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Application
import CloudKit
import OSLog
import UIKit

/// 招待リンクを開いたときに OS が渡してくる参加の情報から、招待リンクを取り出して `inbox` に入れる。
// SwiftUI の App には、参加の情報を受け取る口がない。シーンのデリゲートは UIKit が生成するので、受け皿は型に置く。
@MainActor
public final class InvitationSceneDelegate: NSObject, UIWindowSceneDelegate {
    public static let inbox = InvitationInbox()

    // 起動していなかったときは、こちらで渡される。
    public func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let metadata = connectionOptions.cloudKitShareMetadata else { return }
        Self.receive(metadata)
    }

    public func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Self.receive(cloudKitShareMetadata)
    }
}

// MARK: - Private

private extension InvitationSceneDelegate {
    static func receive(_ metadata: CKShare.Metadata) {
        guard let link = metadata.share.url else {
            Logger.pairing.error("invitation link: 共有の URL が入っていない")
            return
        }
        inbox.received = link
    }
}
