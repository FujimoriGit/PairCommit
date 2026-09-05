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

    static func post(_ nudges: [Nudge], in state: PartnershipState) async {
        let center = UNUserNotificationCenter.current()
        let wanted = Dictionary(nudges.map { (identifier(of: $0), $0) }, uniquingKeysWith: { first, _ in first })
        let delivered = await center.deliveredNotifications().map(\.request.identifier)

        // 解消した催促の通知は残さない。読んだときにはもう終わっている、が起きる。
        center.removeDeliveredNotifications(
            withIdentifiers: delivered.filter { $0.hasPrefix(prefix) && wanted[$0] == nil }
        )

        // 配信済みの催促は出し直さない。同じ識別子で add し直すと、差し替わると同時にもう一度鳴る。
        for (id, nudge) in wanted where !delivered.contains(id) {
            let content = UNMutableNotificationContent()
            content.title = "PairCommit"
            content.body = nudge.message(in: state)
            content.sound = .default
            let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
            try? await center.add(request)
        }
    }

    static func withdrawAll() async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.hasPrefix(prefix) })
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
}
