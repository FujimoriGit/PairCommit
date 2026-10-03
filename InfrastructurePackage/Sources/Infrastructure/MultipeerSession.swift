//
//  MultipeerSession.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Application
import Foundation
import MultipeerConnectivity
import OSLog
import UIKit

/// 近くにいる相手の端末との通信路を開く。
@MainActor
public func makeNearbyChannel() -> any NearbyChannel {
    // iOS 16 以降 UIDevice.name は汎用名を返し、2台とも "iPhone" で衝突しうる。
    MultipeerSession(displayName: "\(UIDevice.current.name.prefix(24))#\(UUID().uuidString.prefix(4))")
}

// MC のデリゲートは任意のスレッドから呼ばれるため、イベントは AsyncStream に流す。
final class MultipeerSession: NSObject, NearbyChannel {
    // MC の制約: 15文字以内・英小文字/数字/ハイフンのみ。
    // 変えるときは Info.plist の NSBonjourServices も同じ値にすること。
    private static let serviceType = "paircommit-pr"

    let events: AsyncStream<NearbyEvent>

    private let eventContinuation: AsyncStream<NearbyEvent>.Continuation
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

    func send(_ text: String) throws(PairingFailure) {
        guard !session.connectedPeers.isEmpty else { throw .disconnected }
        do {
            try session.send(Data(text.utf8), toPeers: session.connectedPeers, with: .reliable)
        } catch {
            Logger.pairing.error("send: \(error, privacy: .public)")
            throw .unexpected
        }
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
        Logger.pairing.error("advertise: \(error, privacy: .public)")
        eventContinuation.yield(.failed)
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
        Logger.pairing.error("browse: \(error, privacy: .public)")
        eventContinuation.yield(.failed)
    }
}
