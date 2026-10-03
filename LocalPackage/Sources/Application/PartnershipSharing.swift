//
//  PartnershipSharing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

import Domain
import Foundation

/// ペアの入った共有を作り、それに参加する。
public protocol PartnershipSharing: Sendable {
    /// - Returns: 作った共有と、相手がそれに参加するための URL。
    func makeShare(initialState: PartnershipState) async throws(PairingFailure) -> (url: URL, share: any PairedShare)
    func acceptShare(from url: URL) async throws(PairingFailure) -> any PairedShare
    /// `PairedShare.save()` で端末に残したもの。
    func savedShare() -> (any PairedShare)?
    func clearSavedShare()
}

/// ペアの入った共有。
public protocol PairedShare: Sendable {
    var isOwner: Bool { get }

    func synchronizer() -> any PartnershipSyncing
    /// 起動し直しても `PartnershipSharing.savedShare()` で戻れるように、端末に残す。
    func save()
    /// 相手の側でもペアが終わる。
    func end() async throws(PairingFailure)
}
