//
//  DiagnosticJournal.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/24
//

import Domain
import Foundation
import OSLog

/// 最近の記録を、iCloud に送れたかどうかにかかわらず端末に残す。
public struct DiagnosticJournal: DiagnosticHistory {
    private let directory = URL.applicationSupportDirectory.appending(path: "DiagnosticJournal", directoryHint: .isDirectory)
    private let logger = Logger.diagnostics

    public init() {}

    public func recentEntries() -> [DiagnosticEntry] {
        let files: [URL]
        do {
            files = try keptFiles()
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch {
            logger.error("journal read: \(error, privacy: .public)")
            return []
        }
        return files.reversed().compactMap { file in
            do {
                let event = try JSONDecoder().decode(DiagnosticEvent.self, from: Data(contentsOf: file))
                return .init(
                    id: event.id,
                    occurredAt: event.occurredAt,
                    isFailure: event.kind == .failure,
                    operation: "\(event.category) \(event.operation)",
                    detail: event.detail
                )
            } catch {
                logger.error("journal read \(file.lastPathComponent, privacy: .public): \(error, privacy: .public)")
                return nil
            }
        }
    }

    func keep(_ event: DiagnosticEvent) {
        do {
            try DiagnosticDirectory.prepare(directory)
            try JSONEncoder().encode(event).write(to: DiagnosticDirectory.file(for: event, in: directory), options: .atomic)
            for old in try keptFiles().dropLast(Self.capacity) {
                try FileManager.default.removeItem(at: old)
            }
        } catch {
            logger.error("journal write \(event.id, privacy: .public): \(error, privacy: .public)")
        }
    }
}

// MARK: - Private

private extension DiagnosticJournal {
    static let capacity = 200

    func keptFiles() throws -> [URL] {
        try DiagnosticDirectory.files(in: directory)
    }
}
