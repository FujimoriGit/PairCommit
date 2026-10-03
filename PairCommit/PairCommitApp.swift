//
//  PairCommitApp.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Application
import Domain
import Infrastructure
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
                sharing: CloudSharing(shareTitle: Self.shareTitle),
                notifications: delegate.notifications,
                makeCriteriaReviewing: {
                    OnDeviceCriteriaReview(instructions: CriteriaReviewPrompt.instructions, prompt: CriteriaReviewPrompt.prompt)
                },
                makeNearbyChannel: makeNearbyChannel
            )
        }
    }
}

// MARK: - Private

private extension PairCommitApp {
    static let shareTitle = "ふたりの帆柱"
}

@MainActor
final class PairCommitDelegate: NSObject, UIApplicationDelegate {
    let session = PartnershipSession()
    let notifications = NudgeNotifications()

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
        // 前面では取り直しで画面が更新され、そちらからも掲示が走る。二重に出すと鳴り直す。
        if application.applicationState != .active {
            let state = store.state
            await notifications.post(for: store.role, in: state) { $0.message(in: state) }
        }
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
