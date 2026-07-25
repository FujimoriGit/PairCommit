//
//  MultipeerSession.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Foundation
import MultipeerConnectivity

enum MultipeerSessionError: LocalizedError {
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConnected: return "相手と接続されていない"
        }
    }
}

// MC のデリゲートは任意のスレッドから呼ばれるため、イベントは AsyncStream に流す。
final class MultipeerSession: NSObject {
    enum Event: Sendable {
        case connected
        case received(String)
        case disconnected
        case failed(String)
    }

    // MC の制約: 15文字以内・英小文字/数字/ハイフンのみ。
    private static let serviceType = "paircommit-pr"

    let events: AsyncStream<Event>

    private let eventContinuation: AsyncStream<Event>.Continuation
    private let myPeerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    /// - Parameter displayName: 招待のタイブレークに使うため、端末間で一意な名前を渡すこと。
    init(displayName: String) {
        (events, eventContinuation) = AsyncStream.makeStream()
        myPeerID = MCPeerID(displayName: displayName)
        session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        eventContinuation.finish()
    }

    func send(_ text: String) throws {
        guard !session.connectedPeers.isEmpty else { throw MultipeerSessionError.notConnected }
        try session.send(Data(text.utf8), toPeers: session.connectedPeers, with: .reliable)
    }
}

// MARK: - MCSessionDelegate

extension MultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            advertiser.stopAdvertisingPeer()
            browser.stopBrowsingForPeers()
            eventContinuation.yield(.connected)
        case .notConnected:
            eventContinuation.yield(.disconnected)
        case .connecting:
            break
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        eventContinuation.yield(.received(text))
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        eventContinuation.yield(.failed("advertise失敗: \(error.localizedDescription)"))
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // 両端が招待し合うのを防ぐため、displayNameが小さい側だけが招待する。
        guard myPeerID.displayName < peerID.displayName else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        eventContinuation.yield(.failed("browse失敗: \(error.localizedDescription)"))
    }
}
