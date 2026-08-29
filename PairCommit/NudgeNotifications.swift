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
        // 同じ催促が続く間は増やさない。識別子が同じ通知は差し替わる。
        let wanted = Dictionary(nudges.map { (identifier(of: $0), $0) }, uniquingKeysWith: { first, _ in first })
        await withdrawVanished(keeping: Set(wanted.keys), on: center)

        for (id, nudge) in wanted {
            let content = UNMutableNotificationContent()
            content.title = "PairCommit"
            content.body = nudge.message(in: state)
            content.sound = .default
            let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
            try? await center.add(request)
        }
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

    // 解消した催促の通知は残さない。読んだときにはもう終わっている、が起きる。
    static func withdrawVanished(keeping wanted: Set<String>, on center: UNUserNotificationCenter) async {
        let delivered = await center.deliveredNotifications()
            .map(\.request.identifier)
            .filter { $0.hasPrefix(prefix) && !wanted.contains($0) }
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }
}
