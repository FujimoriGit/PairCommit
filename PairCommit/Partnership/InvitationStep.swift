//
//  InvitationStep.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain

/// 離れた相手とのペアリングの途中。
enum InvitationStep: Sendable {
    case sending(ownerRole: Role)
    case sent(ownerRole: Role)
    case accepting(any InvitationLink)
    case joined(invitationID: RemoteRecordID)
}
