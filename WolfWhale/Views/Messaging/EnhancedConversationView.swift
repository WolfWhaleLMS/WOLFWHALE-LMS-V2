import SwiftUI

struct EnhancedConversationView: View {
    let conversation: Conversation
    @Bindable var viewModel: AppViewModel

    @State private var realtimeService = RealtimeService()
    @State private var messageText = ""
    @State private var isTyping = false
    @State private var isSubscribed = false
    @State private var moderationWarning: String?
    @State private var showCallView = false
    @FocusState private var isTextFieldFocused: Bool

    // MARK: - Derived State

    private var messages: [ChatMessage] {
        viewModel.conversations.first(where: { $0.id == conversation.id })?.messages ?? conversation.messages
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            if isTyping {
                typingIndicator
            }

            inputBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        let title = conversation.title
                        CallService.shared.startCall(to: title, displayName: title)
                        showCallView = true
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.body)
                    }
                    .tint(.orange)
                    .accessibilityLabel("Start voice call")

                    connectionIndicator
                }
            }
        }
        .onAppear {
            guard !isSubscribed else { return }
            subscribeToRealtime()
            isSubscribed = true
        }
        .onDisappear {
            realtimeService.unsubscribe()
            isSubscribed = false
        }
        .alert("Message Not Sent", isPresented: .constant(moderationWarning != nil)) {
            Button("OK") { moderationWarning = nil }
        } message: {
            Text(moderationWarning ?? "")
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        VStack(spacing: 2) {
                            if shouldShowTimestamp(at: index) {
                                timestampLabel(for: message.timestamp)
                            }
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Messages Yet", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Send a message to start the conversation.")
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom) {
            if message.isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                    .background(
                        bubbleBackground(isCurrentUser: message.isFromCurrentUser),
                        in: .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: message.isFromCurrentUser ? 16 : 4,
                            bottomTrailingRadius: message.isFromCurrentUser ? 4 : 16,
                            topTrailingRadius: 16
                        )
                    )
                    .glassEffect(
                        message.isFromCurrentUser ? .regular.tint(.orange) : .identity,
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

    private func bubbleBackground(isCurrentUser: Bool) -> AnyShapeStyle {
        if isCurrentUser {
            return AnyShapeStyle(.orange)
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    // MARK: - Timestamp Labels

    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index].timestamp
        let previous = messages[index - 1].timestamp
        // Show a timestamp separator when messages are more than 15 minutes apart
        return current.timeIntervalSince(previous) > 900
    }

    private func timestampLabel(for date: Date) -> some View {
        Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            Text("Someone is typing")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView()
                .controlSize(.mini)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message...", text: $messageText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .focused($isTextFieldFocused)
                .accessibilityLabel("Message input")
                .accessibilityHint("Type a message to send")

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .tint(.orange)
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

    // MARK: - Connection Indicator

    private var connectionIndicator: some View {
        Circle()
            .fill(realtimeService.isConnected ? .green : .secondary)
            .frame(width: 8, height: 8)
            .help(realtimeService.isConnected ? "Live" : "Connecting...")
            .accessibilityLabel(realtimeService.isConnected ? "Connected, live updates active" : "Connecting to server")
    }

    // MARK: - Actions

    private func sendMessage() {
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
    }

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

            // If the message is from the current user, the optimistic insert in
            // AppViewModel already added it locally. Check for a recent optimistic
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

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessage = messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}
