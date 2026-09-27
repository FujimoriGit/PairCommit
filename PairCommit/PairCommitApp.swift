//
//  PairCommitApp.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Application
import CloudKit
import Domain
import SwiftUI
import UIKit
import UserNotifications

@main
struct PairCommitApp: App {
    @UIApplicationDelegateAdaptor(PairCommitDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            ContentView(
                session: delegate.session,
                savedPairing: SavedPairing.load(),
                remote: .restored()
            )
        }
    }
}

@MainActor
final class PairCommitDelegate: NSObject, UIApplicationDelegate {
    let session = PartnershipSession()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = PairCommitSceneDelegate.self
        return configuration
    }

    // 取り直しと通知の掲示が終わってから返す。先に返すとバックグラウンドの実行がそこで打ち切られる。
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        guard let store = session.store else { return .noData }
        do {
            try await store.refresh()
        } catch {
            return .failed
        }
        // 前面では取り直しで画面が更新され、そちらからも掲示が走る。二重に出すと鳴り直す。
        if application.applicationState != .active {
            await NudgeNotifications.post(for: store.role, in: store.state)
        }
        return .newData
    }
}

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
        InvitationLinkInbox.shared.received = InvitationLink(metadata: metadata)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        InvitationLinkInbox.shared.received = InvitationLink(metadata: cloudKitShareMetadata)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PairCommitDelegate: UNUserNotificationCenterDelegate {
    // これを返さないと、前面にいる間の通知は iOS が表示しない。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
