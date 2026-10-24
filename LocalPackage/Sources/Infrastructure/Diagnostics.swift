//
//  Diagnostics.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/24
//

import Foundation
import OSLog

/// アプリで起きた失敗と、どのペアを選んだか・終わらせたかの判断を、端末のログ・端末の記録・iCloud に残す。
struct Diagnostics: Sendable {
    static let pairing = Self(category: "pairing")
    static let sync = Self(category: "sync")
    static let notification = Self(category: "notification")
    static let review = Self(category: "review")
    static let application = Self(category: "application")

    private let category: String
    private let logger: Logger

    func failed(_ operation: String, _ error: any Error) {
        failed(operation, because: String(describing: error))
    }

    func failed(_ operation: String, because reason: String) {
        logger.error("\(operation, privacy: .public): \(reason, privacy: .public)")
        keep(event(.failure, operation, reason))
    }

    func decided(_ operation: String, _ detail: String) {
        logger.notice("\(operation, privacy: .public): \(detail, privacy: .public)")
        keep(event(.decision, operation, detail))
    }
}

extension Logger {
    static let diagnostics = Logger(subsystem: subsystemName, category: "diagnostics")
}

// MARK: - Private

private extension Diagnostics {
    init(category: String) {
        self.category = category
        logger = Logger(subsystem: Logger.subsystemName, category: category)
    }

    func keep(_ event: DiagnosticEvent) {
        DiagnosticJournal().keep(event)
        DiagnosticOutbox.shared.post(event)
    }

    func event(_ kind: DiagnosticEvent.Kind, _ operation: String, _ detail: String) -> DiagnosticEvent {
        .init(
            id: UUID(),
            occurredAt: Date(),
            kind: kind,
            category: category,
            operation: operation,
            detail: detail,
            appVersion: Self.appVersion,
            system: ProcessInfo.processInfo.operatingSystemVersionString,
            device: Self.device
        )
    }

    static let appVersion: String = {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }()

    static let device: String = {
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: system.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }()
}

private extension Logger {
    static let subsystemName = "com.fujimori.PairCommit"
}
