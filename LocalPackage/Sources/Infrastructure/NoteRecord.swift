//
//  NoteRecord.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import CloudKit
import Domain
import Foundation

enum NoteRecord {
    static let type = "Note"

    static func decoding(_ record: CKRecord) throws -> Note {
        guard let data = record[Key.note] as? Data else { throw Failure.noteMissing }
        return try JSONDecoder().decode(Note.self, from: data)
    }

    // 親をルートレコードにしないと、ルートレコードの共有に入らず相手から見えない
    static func creating(_ note: Note, under rootRecordID: CKRecord.ID) throws -> CKRecord {
        let record = CKRecord(recordType: type, recordID: id(of: note.id, under: rootRecordID))
        record.setParent(rootRecordID)
        record[Key.note] = try JSONEncoder().encode(note)
        return record
    }

    static func id(of noteID: Note.ID, under rootRecordID: CKRecord.ID) -> CKRecord.ID {
        .init(recordName: "note-\(noteID.uuidString)", zoneID: rootRecordID.zoneID)
    }
}

// MARK: - Private

private extension NoteRecord {
    enum Key {
        static let note = "note"
    }

    enum Failure: Error {
        case noteMissing
    }
}
