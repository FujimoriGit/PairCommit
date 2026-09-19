//
//  NudgeNotifications.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/29
//

import Domain
import UserNotifications

/// 催促を端末の通知として出す。何を催促するかはドメインが決め、ここは出すだけ。
enum NudgeNotifications {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func post(for role: Role, in state: PartnershipState) async {
        let center = UNUserNotificationCenter.current()
        let now = Date.now
        let nudges = state.nudges(for: role, now: now)
        let wanted = Dictionary(nudges.map { (identifier(of: $0), $0) }, uniquingKeysWith: { first, _ in first })
        let delivered = await center.deliveredNotifications().map(\.request.identifier)

        // 解消した催促の通知は残さない。読んだときにはもう終わっている、が起きる。
        center.removeDeliveredNotifications(
            withIdentifiers: delivered.filter { $0.hasPrefix(prefix) && wanted[$0] == nil }
        )

        // 配信済みの催促は出し直さない。同じ識別子で add し直すと、差し替わると同時にもう一度鳴る。
        for (id, nudge) in wanted where !delivered.contains(id) {
            try? await center.add(request(for: nudge, in: state, trigger: nil))
        }

        // 誰も操作しなければプッシュは来ないので、期限が過ぎるだけの催促は先に予約しておく。
        // 予約も同じ識別子で出すので、鳴ったあとは配信済みとして上の重複除けに掛かる。
        // 予約できるのはアプリごとに64件までで、超えた分は発火の遅いものから黙って捨てられる。
        await withdrawPending()
        for (nudge, startsAt) in state.upcomingNudges(for: role, now: now) {
            // 0 以下の間隔を渡すと例外で落ちる
            let interval = max(startsAt.timeIntervalSince(now), 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            try? await center.add(request(for: nudge, in: state, trigger: trigger))
        }
    }

    static func withdrawAll() async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.hasPrefix(prefix) })
        await withdrawPending()
    }
}

// MARK: - Private

private extension NudgeNotifications {
    static let prefix = "nudge."

    static func identifier(of nudge: Nudge) -> String {
        switch nudge {
        case .taskOverdue(let id): "\(prefix)task-overdue.\(id)"
        case .taskDueSoon(let id): "\(prefix)task-due-soon.\(id)"
        case .approvalStalled(let id): "\(prefix)approval-stalled.\(id)"
        case .visionOverdue(let id): "\(prefix)vision-overdue.\(id)"
        }
    }

    static func request(
        for nudge: Nudge,
        in state: PartnershipState,
        trigger: UNNotificationTrigger?
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.body = nudge.message(in: state)
        content.sound = .default
        return UNNotificationRequest(identifier: identifier(of: nudge), content: content, trigger: trigger)
    }

    static func withdrawPending() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.hasPrefix(prefix) })
    }
}
