//
//  InvitationStep.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import CloudKit
import Domain

/// 離れた相手とのペアリングの途中。
enum InvitationStep: Equatable, Sendable {
    case sending(ownerRole: Role)
    case sent(ownerRole: Role)
    case accepting(CKShare.Metadata)
    case joined(invitationID: CKRecord.ID)
}
