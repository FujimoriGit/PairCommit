//
//  NearbyChannel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

/// 近くにいる相手の端末と文字列をやり取りする。
public protocol NearbyChannel: AnyObject {
    var events: AsyncStream<NearbyEvent> { get }

    /// 相手を探し始める。探している間に呼び直すと、すでに見つけた相手も改めて見つけ直す。
    func start()
    func stop()
    func send(_ text: String) throws(PairingFailure)
}

public enum NearbyEvent: Sendable {
    case connected
    case received(String)
    case disconnected
    case failed
}
