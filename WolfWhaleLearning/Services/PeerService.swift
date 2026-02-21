import MultipeerConnectivity
import Observation

nonisolated struct PeerMessage: Identifiable, Codable {
    let id: UUID
    let sender: String
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), sender: String, text: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }
}

@MainActor
@Observable
class PeerService: NSObject {
    var nearbyPeers: [MCPeerID] = []
    var connectedPeers: [MCPeerID] = []
    var isAdvertising = false
    var isBrowsing = false
    var receivedMessages: [PeerMessage] = []

    /// When `true`, incoming peer invitations are accepted automatically.
    /// Set to `false` to require manual acceptance via `pendingInvitation`.
    var autoAcceptInvitations = true

    /// Stores a pending invitation when `autoAcceptInvitations` is `false`.
    /// The UI should present a confirmation dialog and call `respondToInvitation(_:)`.
    var pendingInvitation: (peerID: MCPeerID, handler: ((Bool, MCSession?) -> Void))?

    private let serviceType = "wolfwhale-study"
    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // MARK: - Advertising

    func startAdvertising(displayName: String) {
        let peer = MCPeerID(displayName: displayName)
        peerID = peer

        let newSession = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        newSession.delegate = self
        session = newSession

        let newAdvertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: serviceType)
        newAdvertiser.delegate = self
        advertiser = newAdvertiser
        newAdvertiser.startAdvertisingPeer()
        isAdvertising = true
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        isAdvertising = false
    }

    // MARK: - Browsing

    func startBrowsing() {
        guard let peer = peerID, let _ = session else {
            let peer = MCPeerID(displayName: UIDevice.current.name)
            peerID = peer
            let newSession = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
            newSession.delegate = self
            session = newSession
            startBrowsingInternal(peer: peer)
            return
        }
        startBrowsingInternal(peer: peer)
    }

    private func startBrowsingInternal(peer: MCPeerID) {
        let newBrowser = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        newBrowser.delegate = self
        browser = newBrowser
        newBrowser.startBrowsingForPeers()
        isBrowsing = true
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        isBrowsing = false
        nearbyPeers.removeAll()
    }

    // MARK: - Connection

    func invitePeer(_ peer: MCPeerID) {
        guard let session, let browser else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }

    /// Accept or reject a pending invitation (used when `autoAcceptInvitations` is `false`).
    func respondToInvitation(_ accept: Bool) {
        guard let pending = pendingInvitation else { return }
        pending.handler(accept, accept ? session : nil)
        pendingInvitation = nil
    }

    func disconnect() {
        session?.disconnect()
        stopAdvertising()
        stopBrowsing()
        connectedPeers.removeAll()
        nearbyPeers.removeAll()
        receivedMessages.removeAll()
        pendingInvitation = nil
        peerID = nil
        session = nil
        cleanupTempFiles()
    }

    // MARK: - Messaging

    func sendMessage(_ text: String) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        let message = PeerMessage(sender: peerID?.displayName ?? "Me", text: text)
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            #if DEBUG
            print("[PeerService] Failed to send message: \(error.localizedDescription)")
            #endif
        }
        receivedMessages.append(message)
    }

    func sendFile(_ data: Data, name: String) {
        guard let session else { return }
        for peer in session.connectedPeers {
            session.sendResource(at: saveTemporaryFile(data: data, name: name),
                                 withName: name,
                                 toPeer: peer) { error in
                if let error {
                    #if DEBUG
                    print("PeerService: file send error — \(error.localizedDescription)")
                    #endif
                }
            }
        }
        let message = PeerMessage(sender: peerID?.displayName ?? "Me", text: "Shared file: \(name)")
        receivedMessages.append(message)
    }

    private static let tempSubdirectory = "PeerShared"

    private nonisolated func saveTemporaryFile(data: Data, name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(Self.tempSubdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }

    /// Remove all files in the "PeerShared" temporary subdirectory.
    func cleanupTempFiles() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(Self.tempSubdirectory, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }
}

// MARK: - MCSessionDelegate

extension PeerService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                if !connectedPeers.contains(peerID) {
                    connectedPeers.append(peerID)
                }
                nearbyPeers.removeAll { $0 == peerID }
            case .notConnected:
                connectedPeers.removeAll { $0 == peerID }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = try? JSONDecoder().decode(PeerMessage.self, from: data) {
            Task { @MainActor in
                receivedMessages.append(message)
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        Task { @MainActor in
            let message = PeerMessage(sender: peerID.displayName, text: "Shared file: \(resourceName)")
            receivedMessages.append(message)
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension PeerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            if autoAcceptInvitations {
                #if DEBUG
                print("[PeerService] Auto-accepting invitation from \(peerID.displayName)")
                #endif
                invitationHandler(true, session)
            } else {
                // Store the invitation for the UI to present a confirmation dialog
                pendingInvitation = (peerID: peerID, handler: invitationHandler)
            }
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        #if DEBUG
        print("PeerService: advertising failed — \(error.localizedDescription)")
        #endif
        Task { @MainActor in
            isAdvertising = false
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension PeerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            if !nearbyPeers.contains(peerID) && !connectedPeers.contains(peerID) {
                nearbyPeers.append(peerID)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            nearbyPeers.removeAll { $0 == peerID }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        #if DEBUG
        print("PeerService: browsing failed — \(error.localizedDescription)")
        #endif
        Task { @MainActor in
            isBrowsing = false
        }
    }
}
