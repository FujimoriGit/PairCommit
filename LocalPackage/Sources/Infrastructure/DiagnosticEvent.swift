//
//  DiagnosticEvent.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/24
//

import CloudKit
import Foundation

struct DiagnosticEvent: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case failure
        case decision
        case progress
    }

    let id: UUID
    let occurredAt: Date
    let kind: Kind
    let category: String
    let operation: String
    let detail: String
    let appVersion: String
    let system: String
    let device: String
}

extension DiagnosticEvent {
    static let recordType = "Diagnostic"

    var recordID: CKRecord.ID {
        .init(recordName: id.uuidString)
    }

    func record() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record["occurredAt"] = occurredAt
        record["kind"] = kind.rawValue
        record["category"] = category
        record["operation"] = operation
        record["detail"] = detail
        record["appVersion"] = appVersion
        record["system"] = system
        record["device"] = device
        return record
    }
}
