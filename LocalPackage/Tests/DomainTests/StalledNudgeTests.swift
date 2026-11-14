//
//  StalledNudgeTests.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/07
//

import Domain
import Foundation
import Testing

struct StalledNudgeTests {

    @Test("未完了のタスクが1日動かないと、そのあとの20時に挑む人に進み具合の報告が催促される")
    func taskLeftUntouchedForADayNudgesThePlayerAtEight() throws {
        let (state, visionID) = try Self.visionWithTask(createdAt: at(day: 0, hour: 10))

        let nudges = state.nudges(for: .player, now: at(day: 1, hour: 21), in: utc)

        #expect(nudges == [.progressReportDue(visionID, on: at(day: 1, hour: 20))])
    }

    @Test("タスクが動いてから1日たっていなければ、20時を過ぎても挑む人に進み具合の報告は催促されない")
    func taskTouchedLessThanADayAgoDoesNotNudgeThePlayer() throws {
        let (state, _) = try Self.visionWithTask(createdAt: at(day: 0, hour: 22))

        let nudges = state.nudges(for: .player, now: at(day: 1, hour: 21), in: utc)

        #expect(nudges.isEmpty)
    }

    @Test("タスクが動かないままなら、挑む人には次の日の20時にもう一度進み具合の報告が催促される")
    func taskStillUntouchedNudgesThePlayerAgainTheNextDay() throws {
        let (state, visionID) = try Self.visionWithTask(createdAt: at(day: 0, hour: 10))

        let nudges = state.nudges(for: .player, now: at(day: 2, hour: 21), in: utc)

        #expect(nudges == [.progressReportDue(visionID, on: at(day: 2, hour: 20))])
    }

    @Test("挑む人が書き込むと、そこから1日たつまで挑む人に進み具合の報告は催促されない")
    func playersNoteHoldsOffTheReportNudge() throws {
        let (created, visionID) = try Self.visionWithTask(createdAt: at(day: 0, hour: 10))
        let state = try created.writingNote("少し進んだ", on: .vision(visionID), by: .player, now: at(day: 1, hour: 19))

        let nudges = state.nudges(for: .player, now: at(day: 1, hour: 21), in: utc)

        #expect(nudges.isEmpty)
    }

    @Test("未完了のタスクがなければ、挑む人に進み具合の報告は催促されない")
    func noTaskToDoMeansNoReportNudge() throws {
        let (created, _) = try Self.visionWithTask(createdAt: at(day: 0, hour: 10))
        let state = try created.reportingTask(created.tasks[0].id, by: .player, now: at(day: 0, hour: 11))

        let nudges = state.nudges(for: .player, now: at(day: 5, hour: 21), in: utc)

        #expect(nudges.isEmpty)
    }

    @Test("未完了のタスクが1日動かないと、そのあとの20時に見届ける人に声かけが催促される")
    func taskLeftUntouchedForADayNudgesTheManagerAtEight() throws {
        let (state, visionID) = try Self.visionWithTask(createdAt: at(day: 0, hour: 10))

        let nudges = state.nudges(for: .manager, now: at(day: 1, hour: 21), in: utc)

        #expect(nudges == [.checkInDue(visionID, on: at(day: 1, hour: 20))])
    }

    @Test("見届ける人が書き込むと、そこから1日たつまで見届ける人に声かけは催促されない")
    func managersNoteHoldsOffTheCheckInNudge() throws {
        let (created, visionID) = try Self.visionWithTask(createdAt: at(day: 0, hour: 10))
        let state = try created.writingNote("進んでる？", on: .vision(visionID), by: .manager, now: at(day: 1, hour: 19))

        let nudges = state.nudges(for: .manager, now: at(day: 1, hour: 21), in: utc)

        #expect(nudges.isEmpty)
    }

    @Test(
        "タスクが動かないままなら、最初の催促の前でも後でも、挑む人への進み具合の報告の催促はこの先7回分が予約される",
        arguments: [at(day: 1, hour: 12), at(day: 1, hour: 21)]
    )
    func reportNudgesAreScheduledSevenTimesAhead(now: Date) throws {
        let (state, _) = try Self.visionWithTask(createdAt: at(day: 0, hour: 10))

        let upcoming = state.upcomingNudges(for: .player, now: now, in: utc)

        #expect(upcoming.count == 7)
    }
}

// MARK: - Private

private extension StalledNudgeTests {
    static func visionWithTask(createdAt: Date) throws -> (state: PartnershipState, visionID: Vision.ID) {
        let paired = try PartnershipState().establishingPairing(ownerRole: .manager)
        let drafted = try paired.draftingVision(
            .init(statement: "s", doneCriteria: "c", deadline: nil, why: nil), by: .player, now: at(day: 0, hour: 0)
        )
        let proposed = try drafted.state.proposingVision(drafted.visionID, by: .player, now: at(day: 0, hour: 0))
        let active = try proposed.approvingVision(drafted.visionID, by: .manager, now: at(day: 0, hour: 0))
        return (try active.creatingTask(title: "走る", by: .manager, now: createdAt).state, drafted.visionID)
    }
}

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

// 2027-01-15 00:00 UTC を0日目とする。
private func at(day: Int, hour: Int) -> Date {
    Date(timeIntervalSince1970: 1_799_971_200 + Double(day * 24 + hour) * 60 * 60)
}
