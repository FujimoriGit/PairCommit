//
//  MultipeerSession.swift
//  PairCommit
//  
//  Created by Daiki Fujimori on 2026/06/20
//  


import Foundation
import MultipeerConnectivity
import UIKit

/// Spike: ペアリングの瞬間だけ使うMultipeerConnectivityラッパー。
/// 役割は「CKShareのURL文字列を端末間で直接手渡す」ことだけ。
final class MultipeerSession: NSObject {
    /// serviceTypeは15文字以内・英小文字/数字/ハイフンのみ。
    private static let serviceType = "paircommit-pr"

    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)

    private lazy var session = MCSession(
        peer: myPeerID,
        securityIdentity: nil,
        encryptionPreference: .required
    )
    private lazy var advertiser = MCNearbyServiceAdvertiser(
        peer: myPeerID,
        discoveryInfo: nil,
        serviceType: Self.serviceType
    )
    private lazy var browser = MCNearbyServiceBrowser(
        peer: myPeerID,
        serviceType: Self.serviceType
    )

    /// すべてメインスレッドで呼ばれる。
    var onConnected: (() -> Void)?
    var onReceiveText: ((String) -> Void)?
    var onError: ((String) -> Void)?

    override init() {
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
    }

    func send(_ text: String) {
        guard let data = text.data(using: .utf8),
              !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            emit(onError, error.localizedDescription)
        }
    }

}

// MARK: - Private

private extension MultipeerSession {
    func emit(_ closure: ((String) -> Void)?, _ value: String) {
        DispatchQueue.main.async { closure?(value) }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard state == .connected else { return }
        // 接続が確立したら発見は止める（一回限りのイベント）。
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        DispatchQueue.main.async { self.onConnected?() }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async { self.onReceiveText?(text) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
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
        emit(onError, "advertise失敗: \(error.localizedDescription)")
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
        emit(onError, "browse失敗: \(error.localizedDescription)")
    }
}
