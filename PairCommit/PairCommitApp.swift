//
//  PairCommitApp.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Application
import Domain
import SwiftUI
import UIKit
import UserNotifications

@main
struct PairCommitApp: App {
    @UIApplicationDelegateAdaptor(PairCommitDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            ContentView(session: delegate.session)
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
        await NudgeNotifications.post(store.state.nudges(for: store.role), in: store.state)
        return .newData
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
