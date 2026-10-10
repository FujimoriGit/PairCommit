//
//  PartnerActionNotifications.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import Foundation
import UserNotifications

public struct PartnerActionNotifications: PartnerActionNotifying {
    public init() {}

    public func deliver(_ notices: [PartnerActionNotice]) async {
        let center = UNUserNotificationCenter.current()
        for notice in notices {
            let content = UNMutableNotificationContent()
            content.body = notice.message
            content.sound = .default
            try? await center.add(.init(identifier: Self.identifier(of: notice.action), content: content, trigger: nil))
        }
    }

    public func withdrawAll() async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.hasPrefix(Self.prefix) })
    }
}

// MARK: - Private

private extension PartnerActionNotifications {
    static let prefix = "partner."

    static func identifier(of action: PartnerAction) -> String {
        switch action {
        case .visionProposed(let id): "\(prefix)vision-proposed.\(id)"
        case .visionApproved(let id): "\(prefix)vision-approved.\(id)"
        case .visionReturned(let id): "\(prefix)vision-returned.\(id)"
        case .visionClosed(let id, _): "\(prefix)vision-closed.\(id)"
        case .taskAdded(let id): "\(prefix)task-added.\(id)"
        case .taskProposed(let id): "\(prefix)task-proposed.\(id)"
        case .taskAdopted(let id): "\(prefix)task-adopted.\(id)"
        case .taskReported(let id): "\(prefix)task-reported.\(id)"
        case .taskApproved(let id): "\(prefix)task-approved.\(id)"
        case .taskReturned(let id): "\(prefix)task-returned.\(id)"
        case .taskCancelled(let id): "\(prefix)task-cancelled.\(id)"
        case .reactionChanged(let id, _): "\(prefix)reaction.\(id)"
        case .progressChanged(let id, _): "\(prefix)progress.\(id)"
        case .noteWritten(let id, _): "\(prefix)note.\(id)"
        }
    }
}
