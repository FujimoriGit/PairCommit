//
//  FeedbackTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Domain
import Foundation
import Testing

struct FeedbackTests {

    @Test("見届ける人が完了報告を差し戻すと、その理由がタスクの差し戻しの理由になる")
    func reasonForSendingBackBecomesTheTasksReturnReason() throws {
        // Given
        let (todo, taskID) = try PartnershipState().activeVisionWithTask()
        let reported = try todo.reportingTask(taskID, by: .player)

        // When
        let returned = try reported.returningTask(taskID, feedback: "写真も付けてほしい", by: .manager)

        // Then
        let feedback = try #require(returned.feedback(on: .task(taskID)))
        #expect(feedback.judgment == .returned && feedback.body == "写真も付けてほしい")
    }

    @Test("挑む人が完了を報告し直しても、見届ける人が次に判断するまで差し戻しの理由は残る")
    func returnReasonRemainsUntilTheNextJudgment() throws {
        // Given
        let (todo, taskID) = try PartnershipState().activeVisionWithTask()
        let returned = try todo
            .reportingTask(taskID, by: .player)
            .returningTask(taskID, feedback: "写真も付けてほしい", by: .manager)

        // When
        let reportedAgain = try returned.reportingTask(taskID, by: .player)

        // Then
        #expect(reportedAgain.feedback(on: .task(taskID))?.body == "写真も付けてほしい")
    }

    @Test("2回差し戻すと、あとで書いた理由がタスクの差し戻しの理由になる")
    func laterReasonBecomesTheReturnReason() throws {
        // Given
        let (todo, taskID) = try PartnershipState().activeVisionWithTask()
        let reportedAgain = try todo
            .reportingTask(taskID, by: .player)
            .returningTask(taskID, feedback: "写真も付けてほしい", by: .manager)
            .reportingTask(taskID, by: .player)

        // When
        let returnedAgain = try reportedAgain.returningTask(taskID, feedback: "日付が写っていない", by: .manager)

        // Then
        #expect(returnedAgain.feedback(on: .task(taskID))?.body == "日付が写っていない")
    }

    @Test("差し戻したあと、ひとことを書かずに承認すると、タスクには差し戻しの理由も承認のひとことも無い")
    func approvalWithoutWordsAfterReturnLeavesNoFeedback() throws {
        // Given
        let (todo, taskID) = try PartnershipState().activeVisionWithTask()
        let reportedAgain = try todo
            .reportingTask(taskID, by: .player)
            .returningTask(taskID, feedback: "写真も付けてほしい", by: .manager)
            .reportingTask(taskID, by: .player)

        // When
        let approved = try reportedAgain.approvingTask(taskID, by: .manager)

        // Then
        #expect(approved.feedback(on: .task(taskID)) == nil)
    }

    @Test("見届ける人がひとことを書いて承認すると、それがタスクの承認のひとことになる")
    func wordsOnApprovalBecomeTheTasksApprovalNote() throws {
        // Given
        let (todo, taskID) = try PartnershipState().activeVisionWithTask()
        let reported = try todo.reportingTask(taskID, by: .player)

        // When
        let approved = try reported.approvingTask(taskID, feedback: "よく続けた", by: .manager)

        // Then
        let feedback = try #require(approved.feedback(on: .task(taskID)))
        #expect(feedback.judgment == .approved && feedback.body == "よく続けた")
    }

    @Test("見届ける人がビジョンを差し戻すと、その理由がビジョンの差し戻しの理由になる")
    func reasonForSendingBackBecomesTheVisionsReturnReason() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()

        // When
        let returned = try proposed.rejectingVision(visionID, feedback: "期限を決めてほしい", by: .manager)

        // Then
        let feedback = try #require(returned.feedback(on: .vision(visionID)))
        #expect(feedback.judgment == .returned && feedback.body == "期限を決めてほしい")
    }

    @Test("挑む人がビジョンを出し直しても、見届ける人が判断するまで差し戻しの理由は残る")
    func visionReturnReasonRemainsAfterProposingAgain() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()
        let returned = try proposed.rejectingVision(visionID, feedback: "期限を決めてほしい", by: .manager)

        // When
        let proposedAgain = try returned.proposingVision(visionID, by: .player)

        // Then
        #expect(proposedAgain.feedback(on: .vision(visionID))?.body == "期限を決めてほしい")
    }

    @Test("見届ける人が出し直されたビジョンを承認すると、差し戻しの理由は無くなる")
    func approvingTheVisionClearsTheReturnReason() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()
        let proposedAgain = try proposed
            .rejectingVision(visionID, feedback: "期限を決めてほしい", by: .manager)
            .proposingVision(visionID, by: .player)

        // When
        let approved = try proposedAgain.approvingVision(visionID, by: .manager)

        // Then
        #expect(approved.feedback(on: .vision(visionID)) == nil)
    }

    @Test("承認や差し戻しに添えた言葉は、やりとりに並ばない")
    func wordsOnJudgmentsAreNotPartOfTheExchange() throws {
        // Given
        let (todo, taskID) = try PartnershipState().activeVisionWithTask()
        let reported = try todo
            .writingNote("進んでる？", on: .task(taskID), by: .manager)
            .reportingTask(taskID, by: .player)

        // When
        let returned = try reported.returningTask(taskID, feedback: "写真も付けてほしい", by: .manager)

        // Then
        #expect(returned.exchange(on: .task(taskID)).map(\.body) == ["進んでる？"])
    }

    @Test("どちらの判断か残っていない前の版のフィードバックは、タスクのやりとりに並ぶ")
    func earlierFeedbackWithoutJudgmentStaysInTheTasksExchange() {
        // Given
        let subject = Note.Subject.task(UUID())
        let note = Note(
            id: UUID(),
            subject: subject,
            kind: .feedback(nil),
            author: .manager,
            number: 1,
            body: "a",
            writtenAt: Date()
        )

        // When
        let state = PartnershipState(notes: [note], lastNoteNumber: 1)

        // Then
        #expect(state.exchange(on: subject).map(\.body) == ["a"])
    }

    @Test("どちらの判断か残っていない前の版のフィードバックは、ビジョンの差し戻しの理由になる")
    func earlierFeedbackOnAVisionBecomesTheReturnReason() throws {
        // Given
        let (proposed, visionID) = try PartnershipState().proposedVision()
        let returned = try proposed.rejectingVision(visionID, feedback: "期限を決めてほしい", by: .manager)
        let note = Note(
            id: UUID(),
            subject: .vision(visionID),
            kind: .feedback(nil),
            author: .manager,
            number: 1,
            body: "期限を決めてほしい",
            writtenAt: Date()
        )

        // When
        let state = PartnershipState(visions: returned.visions, notes: [note], lastNoteNumber: 1)

        // Then
        #expect(state.feedback(on: .vision(visionID))?.judgment == .returned)
    }

    @Test("どちらの判断か残っていない前の版のフィードバックを読める")
    func earlierFeedbackWithoutJudgmentCanBeRead() throws {
        // Given
        let note = Note(
            id: UUID(),
            subject: .task(UUID()),
            kind: .feedback(.returned),
            author: .manager,
            number: 1,
            body: "a",
            writtenAt: Date()
        )
        var saved = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(note)) as? [String: Any])
        saved["judgment"] = nil

        // When
        let read = try JSONDecoder().decode(Note.self, from: JSONSerialization.data(withJSONObject: saved))

        // Then
        #expect(read.kind == .feedback(nil))
    }

    @Test("フィードバックは、前の版のアプリが読める種類の名前で保存される")
    func feedbackIsSavedUnderTheKindNameEarlierVersionsRead() throws {
        // Given
        let note = Note(
            id: UUID(),
            subject: .task(UUID()),
            kind: .feedback(.approved),
            author: .manager,
            number: 1,
            body: "a",
            writtenAt: Date()
        )

        // When
        let saved = try JSONEncoder().encode(note)

        // Then
        let object = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        #expect(object["kind"] as? String == "feedback")
    }
}
