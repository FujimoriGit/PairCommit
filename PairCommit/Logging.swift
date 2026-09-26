//
//  Logging.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/26
//

import OSLog

extension Logger {
    static let pairing = Logger(subsystem: subsystemName, category: "pairing")
    static let sync = Logger(subsystem: subsystemName, category: "sync")
}

// MARK: - Private

private extension Logger {
    static let subsystemName = "com.fujimori.PairCommit"
}
