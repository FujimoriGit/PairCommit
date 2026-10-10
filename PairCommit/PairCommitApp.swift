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
                sharing: delegate.sharing,
                inviting: CloudInviting(shareTitle: Self.shareTitle),
                invitationLinks: InvitationSceneDelegate.links,
                notifications: delegate.notifications,
                partnerNotifications: delegate.partnerNotifications,
                knownState: delegate.knownState,
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
    static let shareTitle = String(localized: .shareTitle)
}

@MainActor
final class PairCommitDelegate: NSObject, UIApplicationDelegate {
    let session = PartnershipSession()
    let sharing = CloudSharing(shareTitle: PairCommitApp.shareTitle)
    let notifications = NudgeNotifications()
    let partnerNotifications = PartnerActionNotifications()
    let knownState = SavedKnownState()

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
        configuration.delegateClass = InvitationSceneDelegate.self
        return configuration
    }

    // 取り直しと通知の掲示が終わってから返す。先に返すとバックグラウンドの実行がそこで打ち切られる。
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        // 取り直すと画面の側が新しい状態を残すので、その前に読む。
        let known = knownState.lastKnown()
        let store: PartnershipStore
        do throws(SyncFailure) {
            if let current = session.store {
                try await current.refresh()
                store = current
            } else if let share = sharing.savedShare(), let started = try await PartnershipStore(starting: share) {
                store = started
            } else {
                return .noData
            }
        } catch {
            return .failed
        }
        let state = store.state
        // 前面では取り直しで画面が更新され、そちらからも掲示が走る。二重に出すと鳴り直す。
        if application.applicationState != .active {
            await notifications.post(for: store.role, in: state) { $0.message(in: state) }
            if let known {
                await partnerNotifications.post(for: store.role, in: state, since: known) { $0.message(in: state) }
            }
        }
        knownState.keep(state)
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
