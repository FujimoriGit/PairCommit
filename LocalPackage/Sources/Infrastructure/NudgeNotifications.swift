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
        let upcoming = notices.compactMap { notice in
            notice.startsAt.map {
                (id: Self.identifier(of: notice.nudge), notice: notice, fireAt: max($0, now.addingTimeInterval(1)))
            }
        }
        let delivered = await center.deliveredNotifications().map(\.request.identifier)

        // 消した通知は配信済みに残らないので、配信済みかどうかでは出し直しを防げない。
        // 催促ごとに鳴らした時刻（予約したものは鳴る時刻）を端末に残し、その時刻を過ぎた催促は解消するまで出し直さない。
        // 予約の時刻より前に始まった催促（期限を前に動かしたときなど）はまだ鳴っていないので、すぐ出す。
        let rung = Self.ringTimes() ?? Dictionary(delivered.map { ($0, now) }, uniquingKeysWith: { first, _ in first })
        let alreadyRung = rung.filter { current[$0.key] != nil && $0.value <= now }

        // 解消した催促の通知は残さない。読んだときにはもう終わっている、が起きる。
        center.removeDeliveredNotifications(
            withIdentifiers: delivered.filter { $0.hasPrefix(Self.prefix) && current[$0] == nil }
        )

        var rungNow: [String: Date] = [:]
        for (id, notice) in current where alreadyRung[id] == nil {
            do {
                try await center.add(Self.request(for: notice, trigger: nil))
                rungNow[id] = now
            } catch {
                Diagnostics.notification.failed("add nudge \(id)", error)
            }
        }

        // 誰も操作しなければプッシュは来ないので、期限が過ぎるだけの催促は先に予約しておく。
        // 未配信の予約は同じ識別子の add で置き換わるので、消すのは予約しなくなったものだけにする。
        await Self.withdrawPending(keeping: Set(upcoming.map(\.id)))
        for (id, notice, fireAt) in upcoming {
            do {
                try await center.add(Self.request(for: notice, trigger: Self.trigger(at: fireAt)))
            } catch {
                Diagnostics.notification.failed("schedule nudge \(id)", error)
            }
        }

        // 予約できるのはアプリごとに64件までで、超えた分は発火の遅いものから黙って捨てられる。
        // add が失敗したものや予約の一覧に残らなかったものは鳴らないので、一覧にあるものだけを鳴るものとして残す。
        let pending = Set(await center.pendingNotificationRequests().map(\.identifier))
        let scheduled = Dictionary(
            upcoming.filter { pending.contains($0.id) }.map { ($0.id, $0.fireAt) },
            uniquingKeysWith: { first, _ in first }
        )
        Self.keepRingTimes(alreadyRung.merging(rungNow) { $1 }.merging(scheduled) { $1 })
    }

    public func withdrawAll() async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.hasPrefix(Self.prefix) })
        await Self.withdrawPending(keeping: [])
        UserDefaults.standard.removeObject(forKey: Self.ringTimesKey)
    }
}

// MARK: - Private

private extension NudgeNotifications {
    static let prefix = "nudge."
    static let ringTimesKey = "nudge.ringTimes"

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

    static func ringTimes() -> [String: Date]? {
        UserDefaults.standard.dictionary(forKey: ringTimesKey) as? [String: Date]
    }

    static func keepRingTimes(_ times: [String: Date]) {
        UserDefaults.standard.set(times, forKey: ringTimesKey)
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
    // `repeats: false` では、すでに過ぎた時刻の成分を渡すと一度も発火しない。呼ぶ側で今より後にしておく。
    static func trigger(at fireAt: Date) -> UNCalendarNotificationTrigger {
        .init(
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
