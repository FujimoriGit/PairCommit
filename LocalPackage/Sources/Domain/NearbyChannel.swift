//
//  NearbyChannel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/03
//

/// 近くにいる相手の端末との通信路を開く。
public protocol NearbyChannelOpening {
    /// 開いた通信路は、止めると使えなくなる。ペアリングを始めるたびに開き直す。
    @MainActor
    func openChannel() -> any NearbyChannel
}

/// 近くにいる相手の端末と文字列をやり取りする。
public protocol NearbyChannel: AnyObject {
    var events: AsyncStream<NearbyEvent> { get }

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
