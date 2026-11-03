//
//  PartnershipSessionDoubles.swift
//  PairCommitTests
//
//  Created by Daiki Fujimori on 2026/11/03
//

import Application
import Domain
import Foundation

extension PartnershipSession {
    static func make(
        saved: (any PairedShare)? = nil,
        remaining: (any PairedShare)? = nil,
        joined: (any PairedShare)? = nil,
        nudges: any NudgeNotifying = SilentNudges(),
        announcement: PartnerActionAnnouncement = .quiet,
        failures: RecordedFailures = .init()
    ) -> PartnershipSession {
        .init(
            sharing: StubSharing(saved: saved, remaining: remaining),
            inviting: IdleInviting(joined: joined),
            nudges: nudges,
            announcement: announcement,
            failures: failures,
            nudgeMessage: { _, _ in "" },
            makeNearbyChannel: { SilentChannel() }
        )
    }
}

struct StubSharing: PartnershipSharing {
    let saved: (any PairedShare)?
    let remaining: (any PairedShare)?

    func makeShare(initialState: PartnershipState) async throws(PairingFailure) -> (url: URL, share: any PairedShare) {
        throw .unexpected
    }

    func acceptShare(from url: URL) async throws(PairingFailure) -> any PairedShare {
        throw .unexpected
    }

    func savedShare() -> (any PairedShare)? {
        saved
    }

    func remainingShare() async throws(PairingFailure) -> (any PairedShare)? {
        remaining
    }

    func declineRemainingShare() {}

    func clearSavedShare() {}
}

struct IdleInviting: PartnershipInviting {
    let joined: (any PairedShare)?

    func send() async throws(PairingFailure) -> URL {
        throw .unexpected
    }

    func advance(ownerRole: Role) async throws(PairingFailure) -> InvitationProgress {
        throw .unexpected
    }

    func withdraw() async throws(PairingFailure) {}

    func join(_ link: URL) async throws(PairingFailure) {
        guard joined != nil else { throw .unexpected }
    }

    func advanceJoining() async throws(PairingFailure) -> (any PairedShare)? {
        guard let joined else { throw .unexpected }
        return joined
    }

    func leave() async throws(PairingFailure) {}

    func endPair() async throws(PairingFailure) {}

    func savedStage() -> InvitationStage? {
        nil
    }

    func savedWithdrawal() -> Withdrawal? {
        nil
    }

    func save(_ stage: InvitationStage) {}

    func save(_ withdrawal: Withdrawal) {}

    func clearSaved() {}
}

struct SilentNudges: NudgeNotifying {
    func requestPermission() async {}

    func replace(with notices: [NudgeNotice], now: Date) async {}

    func withdrawAll() async {}
}

final class SilentChannel: NearbyChannel {
    let events = AsyncStream<NearbyEvent> { $0.finish() }

    func start() {}

    func stop() {}

    func send(_ text: String) throws(PairingFailure) {}
}
