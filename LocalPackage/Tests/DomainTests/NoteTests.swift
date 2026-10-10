//
//  NoteTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import Foundation
import Testing

struct NoteTests {

    @Test("挑む人がタスクに状況報告を書くと、そのタスクの書き込みに並ぶ")
    func reportWrittenByThePlayerAppearsOnTheTask() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When
        let written = try state.writingNote("2回目まで終わった", kind: .report, on: .task(taskID), by: .player)

        // Then
        #expect(written.notes(on: .task(taskID)).map(\.body) == ["2回目まで終わった"])
    }

    @Test("見届ける人は状況報告を書けない")
    func managerCannotWriteAReport() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        #expect(throws: DomainError.roleForbidden(required: .player)) {
            try state.writingNote("進んでる？", kind: .report, on: .task(taskID), by: .manager)
        }
    }

    @Test("書き込みには、書いた順に1から番号が振られる")
    func notesAreNumberedInTheOrderWritten() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()
        let first = try state.writingNote("進んでる？", kind: .reminder, on: .task(taskID), by: .manager)

        // When
        let second = try first.writingNote("半分まで来た", kind: .report, on: .task(taskID), by: .player)

        // Then
        #expect(second.notes(on: .task(taskID)).map(\.number) == [1, 2])
    }

    @Test("空白だけの書き込みはできない")
    func blankNoteIsRefused() throws {
        // Given
        let (state, taskID) = try PartnershipState().activeVisionWithTask()

        // When / Then
        #expect(throws: DomainError.blankText) {
            try state.writingNote("  \n", kind: .feedback, on: .task(taskID), by: .manager)
        }
    }

    @Test("閉じたビジョンのタスクには書き込めない")
    func taskOfAClosedVisionCannotBeWrittenOn() throws {
        // Given
        let (active, visionID) = try PartnershipState().activeVision()
        let (created, taskID) = try active.creatingTask(title: "t", by: .manager)
        let closed = try created.closingVision(visionID, as: .achieved, by: .manager)

        // When / Then
        #expect(throws: DomainError.noteSubjectClosed) {
            try closed.writingNote("おつかれさま", kind: .feedback, on: .task(taskID), by: .manager)
        }
    }

    @Test("取り下げた起案に書いた書き込みは、起案と一緒に消える")
    func notesOnADiscardedDraftAreRemoved() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()
        let returned = try proposed.rejectingVision(visionID, by: .manager)
        let written = try returned.writingNote("期限を決めてほしい", kind: .feedback, on: .vision(visionID), by: .manager)

        // When
        let discarded = try written.discardingVision(visionID, by: .player)

        // Then
        #expect(discarded.notes(on: .vision(visionID)).isEmpty)
    }

    @Test("挑む人が書き込むと、見届ける人にその書き込みが知らされる")
    func noteByThePlayerIsToldToTheManager() throws {
        // Given
        let (before, taskID) = try PartnershipState().activeVisionWithTask()
        let after = try before.writingNote("今日は休む", kind: .report, on: .task(taskID), by: .player)
        let noteID = try #require(after.notes.first?.id)

        // When
        let actions = after.partnerActions(since: before, for: .manager)

        // Then
        #expect(actions == [.noteWritten(noteID, author: .player)])
    }
}
