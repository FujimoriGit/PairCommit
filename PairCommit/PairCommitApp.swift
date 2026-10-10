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
        let reception = PartnerChangeReception(
            knownState: knownState,
            nudges: notifications,
            partnerActions: partnerNotifications,
            nudgeMessage: { $0.message(in: $1) },
            partnerActionMessage: { $0.message(in: $1) }
        )
        do throws(SyncFailure) {
            let received = try await reception.receive(
                into: session.store,
                orStartingFrom: sharing.savedShare(),
                isActive: application.applicationState == .active
            )
            return received ? .newData : .noData
        } catch {
            return .failed
        }
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
