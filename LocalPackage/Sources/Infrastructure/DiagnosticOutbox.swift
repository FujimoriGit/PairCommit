//
//  DiagnosticOutbox.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/24
//

import CloudKit
import Foundation
import OSLog

/// 記録を端末に書き置き、iCloud に送れたものから消す。
struct DiagnosticOutbox: Sendable {
    static let shared = Self(
        directory: .applicationSupportDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory),
        database: PartnershipShare.container.publicCloudDatabase
    )

    private let directory: URL
    private let database: CKDatabase
    private let logger = Logger.diagnostics

    func post(_ event: DiagnosticEvent) {
        write(event)
        Task { await send() }
    }

    /// 書き置いたまま送れていない記録を送る。
    func send() async {
        let pending = pendingEvents()
        guard !pending.isEmpty else { return }
        let results: [CKRecord.ID: Result<CKRecord, any Error>]
        do {
            // 同じ記録を2度送っても、同じ ID のレコードを同じ中身で上書きするだけになる。
            results = try await database.modifyRecords(
                saving: pending.map { $0.event.record() },
                deleting: [],
                savePolicy: .allKeys,
                atomically: false
            ).saveResults
        } catch {
            logger.error("send: \(error, privacy: .public)")
            return
        }
        for (file, event) in pending {
            switch results[event.recordID] {
            case .success:
                remove(file)
            case .failure(let error):
                logger.error("send \(event.id, privacy: .public): \(error, privacy: .public)")
            case nil:
                logger.error("send \(event.id, privacy: .public): 結果が返っていない")
            }
        }
    }
}

// MARK: - Private

private extension DiagnosticOutbox {
    static let capacity = 200

    func write(_ event: DiagnosticEvent) {
        do {
            try DiagnosticDirectory.prepare(directory)
            guard try pendingFiles().count < Self.capacity else {
                logger.error("write \(event.id, privacy: .public): 送れていない記録が上限に達している")
                return
            }
            try JSONEncoder().encode(event).write(to: DiagnosticDirectory.file(for: event, in: directory), options: .atomic)
        } catch {
            logger.error("write \(event.id, privacy: .public): \(error, privacy: .public)")
        }
    }

    func pendingFiles() throws -> [URL] {
        try DiagnosticDirectory.files(in: directory)
    }

    func pendingEvents() -> [(file: URL, event: DiagnosticEvent)] {
        let files: [URL]
        do {
            files = try pendingFiles()
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch {
            logger.error("read: \(error, privacy: .public)")
            return []
        }
        return files.compactMap { file in
            do {
                return (file, try JSONDecoder().decode(DiagnosticEvent.self, from: Data(contentsOf: file)))
            } catch {
                // 読めない記録は何度送ろうとしても読めないので、残さない。
                logger.error("read \(file.lastPathComponent, privacy: .public): \(error, privacy: .public)")
                remove(file)
                return nil
            }
        }
    }

    func remove(_ file: URL) {
        do {
            try FileManager.default.removeItem(at: file)
        } catch CocoaError.fileNoSuchFile {
            // 並んで走ったほうの送信が、先に消している。
        } catch {
            logger.error("remove \(file.lastPathComponent, privacy: .public): \(error, privacy: .public)")
        }
    }
}

/// 記録を1件ずつファイルにして置くフォルダ。
enum DiagnosticDirectory {
    static func prepare(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excluded = directory
        try excluded.setResourceValues(values)
    }

    // ファイル名の先頭を時刻にして、名前の順が起きた順になるようにする。
    static func file(for event: DiagnosticEvent, in directory: URL) -> URL {
        let milliseconds = Int(event.occurredAt.timeIntervalSince1970 * 1000)
        return directory.appending(path: "\(milliseconds)-\(event.id.uuidString).json")
    }

    /// - Returns: 古い順。
    static func files(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
