//
//  Withdrawal.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/28
//

import CloudKit

/// やめる後始末で片付けるもの。
enum Withdrawal {
    case invitation
    case membership(invitationID: CKRecord.ID)
    case pair(PairedShare)
}
