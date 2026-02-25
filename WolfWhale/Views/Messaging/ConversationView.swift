import SwiftUI

struct ConversationView: View {
    let conversation: Conversation
    @Bindable var viewModel: AppViewModel
    @State private var realtimeService = RealtimeService()
    @State private var messageText = ""
    @State private var moderationWarning: String?
    @FocusState private var isTextFieldFocused: Bool

    private var messages: [ChatMessage] {
        viewModel.conversations.first(where: { $0.id == conversation.id })?.messages ?? conversation.messages
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            inputBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Circle()
                    .fill(realtimeService.isConnected ? .green : .gray)
                    .frame(width: 8, height: 8)
                    .help(realtimeService.isConnected ? "Live" : "Connecting...")
                    .accessibilityLabel(realtimeService.isConnected ? "Connected, live updates active" : "Connecting to server")
            }
        }
        .onAppear {
            subscribeToRealtime()
        }
        .onDisappear {
            realtimeService.unsubscribe()
        }
        .alert("Message Not Sent", isPresented: .constant(moderationWarning != nil)) {
            Button("OK") { moderationWarning = nil }
        } message: {
            Text(moderationWarning ?? "")
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isFromCurrentUser ? .blue : Color(.tertiarySystemFill),
                        in: .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: message.isFromCurrentUser ? 16 : 4,
                            bottomTrailingRadius: message.isFromCurrentUser ? 4 : 16,
                            topTrailingRadius: 16
                        )
                    )
                    .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                    .glassEffect(
                        message.isFromCurrentUser ? .regular.tint(.purple) : .identity,
                        in: RoundedRectangle(cornerRadius: 16)
                    )

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !message.isFromCurrentUser { Spacer(minLength: 60) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.isFromCurrentUser ? "You" : message.senderName) said: \(message.content), at \(message.timestamp.formatted(.dateTime.hour().minute()))")
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message...", text: $messageText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemFill), in: Capsule())
                .focused($isTextFieldFocused)
                .accessibilityLabel("Message input")
                .accessibilityHint("Type a message to send")

            Button {
                let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }

                // COPPA content moderation check
                let moderation = ContentModerationService.shared.moderateContent(trimmed)
                if !moderation.isClean {
                    moderationWarning = moderation.flaggedReason
                    return
                }

                viewModel.sendMessage(in: conversation.id, text: trimmed)
                messageText = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .sensoryFeedback(.impact(weight: .light), trigger: messages.count)
            .accessibilityLabel("Send message")
            .accessibilityHint("Double tap to send your message")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .glassEffect(.regular, in: .rect(cornerRadius: 0))
    }

    // MARK: - Realtime Subscription

    private func subscribeToRealtime() {
        let currentUserId = viewModel.currentUser?.id

        realtimeService.subscribeToConversation(
            conversation.id,
            currentUserId: currentUserId
        ) { incomingMessage in
            guard let convIndex = viewModel.conversations.firstIndex(where: { $0.id == conversation.id }) else {
                return
            }

            // Avoid duplicate messages by ID
            let isDuplicate = viewModel.conversations[convIndex].messages.contains(where: { $0.id == incomingMessage.id })
            guard !isDuplicate else { return }

            // If the message is from the current user, check for a recent optimistic
            // duplicate (same content within 5 seconds) and skip if found.
            if incomingMessage.isFromCurrentUser {
                let recentDuplicate = viewModel.conversations[convIndex].messages.contains {
                    $0.isFromCurrentUser && $0.content == incomingMessage.content &&
                    abs($0.timestamp.timeIntervalSince(incomingMessage.timestamp)) < 5
                }
                if recentDuplicate { return }
            }

            viewModel.conversations[convIndex].messages.append(incomingMessage)
            viewModel.conversations[convIndex].lastMessage = incomingMessage.content
            viewModel.conversations[convIndex].lastMessageDate = incomingMessage.timestamp
        }
    }
}
