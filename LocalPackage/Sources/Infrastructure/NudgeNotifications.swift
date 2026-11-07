//
//  NudgeNotifications.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/29
//

import Domain
import Foundation
import UserNotifications

public struct NudgeNotifications: NudgeNotifying {
    public init() {}

    public func requestPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            Diagnostics.notification.failed("requestAuthorization", error)
        }
    }

    public func replace(with notices: [NudgeNotice], now: Date) async {
        let center = UNUserNotificationCenter.current()
        let current = Dictionary(
            notices.filter { $0.startsAt == nil }.map { (Self.identifier(of: $0.nudge), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let upcoming = notices.compactMap { notice in notice.startsAt.map { (notice, $0) } }
        let upcomingIDs = Set(upcoming.map { Self.identifier(of: $0.0.nudge) })
        let delivered = await center.deliveredNotifications().map(\.request.identifier)

        // 押したり消したりした通知は配信済みに残らないので、配信済みかどうかでは出し直しを防げない。
        // 出した催促と予約した催促を端末に残し、解消するまでは出し直さない。
        let notified = Self.notified() ?? Set(delivered)
        Self.keepNotified(Set(current.keys).union(upcomingIDs))

        // 解消した催促の通知は残さない。読んだときにはもう終わっている、が起きる。
        center.removeDeliveredNotifications(
            withIdentifiers: delivered.filter { $0.hasPrefix(Self.prefix) && current[$0] == nil }
        )

        for (id, notice) in current where !notified.contains(id) {
            do {
                try await center.add(Self.request(for: notice, trigger: nil))
            } catch {
                Diagnostics.notification.failed("add nudge \(id)", error)
            }
        }

        // 誰も操作しなければプッシュは来ないので、期限が過ぎるだけの催促は先に予約しておく。
        // 未配信の予約は同じ識別子の add で置き換わるので、消すのは予約しなくなったものだけにする。
        // 予約できるのはアプリごとに64件までで、超えた分は発火の遅いものから黙って捨てられる。
        await Self.withdrawPending(keeping: upcomingIDs)
        for (notice, startsAt) in upcoming {
            do {
                try await center.add(Self.request(for: notice, trigger: Self.trigger(at: startsAt, after: now)))
            } catch {
                Diagnostics.notification.failed("schedule nudge \(Self.identifier(of: notice.nudge))", error)
            }
        }
    }

    public func withdrawAll() async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.hasPrefix(Self.prefix) })
        await Self.withdrawPending(keeping: [])
        UserDefaults.standard.removeObject(forKey: Self.notifiedKey)
    }
}

// MARK: - Private

private extension NudgeNotifications {
    static let prefix = "nudge."
    static let notifiedKey = "nudge.notified"

    static func identifier(of nudge: Nudge) -> String {
        switch nudge {
        case .taskOverdue(let id): "\(prefix)task-overdue.\(id)"
        case .taskDueSoon(let id): "\(prefix)task-due-soon.\(id)"
        case .approvalStalled(let id): "\(prefix)approval-stalled.\(id)"
        case .visionOverdue(let id): "\(prefix)vision-overdue.\(id)"
        case .progressReportDue(let id, let day): "\(prefix)progress-report-due.\(id).\(Int(day.timeIntervalSince1970))"
        case .checkInDue(let id, let day): "\(prefix)check-in-due.\(id).\(Int(day.timeIntervalSince1970))"
        }
    }

    static func notified() -> Set<String>? {
        UserDefaults.standard.stringArray(forKey: notifiedKey).map(Set.init)
    }

    static func keepNotified(_ identifiers: Set<String>) {
        UserDefaults.standard.set(Array(identifiers), forKey: notifiedKey)
    }

    static func request(for notice: NudgeNotice, trigger: UNNotificationTrigger?) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.body = notice.message
        content.sound = .default
        content.userInfo = notice.nudge.subject.notificationUserInfo
        return UNNotificationRequest(identifier: identifier(of: notice.nudge), content: content, trigger: trigger)
    }

    // 経過秒で予約すると、端末の時計を直しても追随しない。タイムゾーンを外すと、成分は発火を待つ時点の
    // タイムゾーンで読まれるので、移動するとずれる。期限は絶対時刻なので、鳴る時刻も絶対時刻で渡す。
    static func trigger(at startsAt: Date, after now: Date) -> UNCalendarNotificationTrigger {
        // `repeats: false` では、すでに過ぎた時刻の成分を渡すと一度も発火しない。
        let fireAt = max(startsAt, now.addingTimeInterval(1))
        return .init(
            dateMatching: Calendar.current.dateComponents(
                [.timeZone, .year, .month, .day, .hour, .minute, .second],
                from: fireAt
            ),
            repeats: false
        )
    }

    static func withdrawPending(keeping kept: Set<String>) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(
            withIdentifiers: pending.filter { $0.hasPrefix(prefix) && !kept.contains($0) }
        )
    }
}
