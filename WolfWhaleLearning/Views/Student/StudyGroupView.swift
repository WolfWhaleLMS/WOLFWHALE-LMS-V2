import SwiftUI
import MultipeerConnectivity

struct StudyGroupView: View {
    @StateObject private var peerService = PeerService()
    @State private var displayName = UIDevice.current.name
    @State private var messageText = ""
    @State private var isHosting = false
    @State private var hapticTrigger = false
    @State private var showShareNotes = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                connectionCard
                if peerService.isAdvertising || peerService.isBrowsing {
                    nearbyPeersSection
                    connectedPeersSection
                    if !peerService.connectedPeers.isEmpty {
                        chatSection
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Study Groups")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            peerService.disconnect()
        }
        .sheet(isPresented: $showShareNotes) {
            shareNotesSheet
        }
    }

    // MARK: - Connection Card

    private var connectionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 36))
                .foregroundStyle(.teal)
                .symbolEffect(.pulse, isActive: peerService.isAdvertising || peerService.isBrowsing)

            if peerService.isAdvertising || peerService.isBrowsing {
                VStack(spacing: 4) {
                    Text(isHosting ? "Hosting Study Group" : "Looking for Groups")
                        .font(.headline)
                    Text("\(peerService.connectedPeers.count) student\(peerService.connectedPeers.count == 1 ? "" : "s") connected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    hapticTrigger.toggle()
                    peerService.disconnect()
                    isHosting = false
                } label: {
                    Label("Leave Group", systemImage: "xmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.12), in: Capsule())
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            } else {
                Text("Study Together Nearby")
                    .font(.headline)
                Text("Connect with classmates nearby using peer-to-peer. No internet needed!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button {
                        hapticTrigger.toggle()
                        isHosting = true
                        peerService.startAdvertising(displayName: displayName)
                        peerService.startBrowsing()
                    } label: {
                        Label("Start Group", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.teal.gradient, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

                    Button {
                        hapticTrigger.toggle()
                        isHosting = false
                        peerService.startAdvertising(displayName: displayName)
                        peerService.startBrowsing()
                    } label: {
                        Label("Join Group", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.teal)
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Nearby Peers

    private var nearbyPeersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Students")
                    .font(.headline)
                Spacer()
                if peerService.isBrowsing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if peerService.nearbyPeers.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(.secondary)
                    Text("Scanning for nearby students...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            } else {
                ForEach(peerService.nearbyPeers, id: \.displayName) { peer in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.teal.gradient)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(String(peer.displayName.prefix(1)).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(peer.displayName)
                                .font(.subheadline.bold())
                            Text("Available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            hapticTrigger.toggle()
                            peerService.invitePeer(peer)
                        } label: {
                            Text("Invite")
                                .font(.caption.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(.teal.gradient, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Connected Peers

    private var connectedPeersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected")
                .font(.headline)

            if peerService.connectedPeers.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(.secondary)
                    Text("No one connected yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            } else {
                ForEach(peerService.connectedPeers, id: \.displayName) { peer in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.green.gradient)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(String(peer.displayName.prefix(1)).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(peer.displayName)
                                .font(.subheadline.bold())
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Group Chat")
                    .font(.headline)
                Spacer()
                Button {
                    hapticTrigger.toggle()
                    showShareNotes = true
                } label: {
                    Label("Share Notes", systemImage: "doc.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.teal)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }

            VStack(spacing: 8) {
                if peerService.receivedMessages.isEmpty {
                    Text("No messages yet. Say hello!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(peerService.receivedMessages) { message in
                                messageBubble(message)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 250)
                }

                HStack(spacing: 10) {
                    TextField("Message...", text: $messageText)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Capsule())

                    Button {
                        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        hapticTrigger.toggle()
                        peerService.sendMessage(messageText)
                        messageText = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.teal)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
    }

    private func messageBubble(_ message: PeerMessage) -> some View {
        let isMe = message.sender == (UIDevice.current.name)
        return HStack {
            if isMe { Spacer(minLength: 40) }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if !isMe {
                    Text(message.sender)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMe ? AnyShapeStyle(.teal.gradient) : AnyShapeStyle(.ultraThinMaterial),
                                in: .rect(cornerRadius: 16))
                    .foregroundStyle(isMe ? .white : .primary)
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !isMe { Spacer(minLength: 40) }
        }
    }

    // MARK: - Share Notes Sheet

    private var shareNotesSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.teal)

                Text("Share Study Notes")
                    .font(.title3.bold())

                Text("Send a sample note to everyone in the group.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    let sampleNote = "Study notes shared from WolfWhale LMS".data(using: .utf8) ?? Data()
                    peerService.sendFile(sampleNote, name: "StudyNotes.txt")
                    showShareNotes = false
                } label: {
                    Label("Send Notes", systemImage: "paperplane.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.teal.gradient, in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 40)
            }
            .padding(30)
            .navigationTitle("Share Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showShareNotes = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
