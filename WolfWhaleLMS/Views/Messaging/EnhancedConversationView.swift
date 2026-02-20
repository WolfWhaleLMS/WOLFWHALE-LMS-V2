import SwiftUI

struct EnhancedConversationView: View {
    let conversation: Conversation
    @Bindable var viewModel: AppViewModel

    @State private var realtimeService = RealtimeService()
    @State private var messageText = ""
    @State private var isTyping = false
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
                connectionIndicator
            }
        }
        .onAppear {
            subscribeToRealtime()
        }
        .onDisappear {
            realtimeService.unsubscribe()
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

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !message.isFromCurrentUser { Spacer(minLength: 60) }
        }
    }

    private func bubbleBackground(isCurrentUser: Bool) -> AnyShapeStyle {
        if isCurrentUser {
            return AnyShapeStyle(.pink)
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

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .tint(.pink)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .sensoryFeedback(.impact(weight: .light), trigger: messages.count)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Connection Indicator

    private var connectionIndicator: some View {
        Circle()
            .fill(realtimeService.isConnected ? .green : .gray)
            .frame(width: 8, height: 8)
            .help(realtimeService.isConnected ? "Live" : "Connecting...")
    }

    // MARK: - Actions

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        viewModel.sendMessage(in: conversation.id, text: trimmed)
        messageText = ""
    }

    private func subscribeToRealtime() {
        let currentUserId = viewModel.currentUser?.id

        realtimeService.subscribeToConversation(conversation.id) { incomingMessage in
            // Skip if this message was sent by the current user
            // (the local optimistic insert in AppViewModel already handles that)
            guard let convIndex = viewModel.conversations.firstIndex(where: { $0.id == conversation.id }) else {
                return
            }

            // Avoid duplicate messages
            let isDuplicate = viewModel.conversations[convIndex].messages.contains(where: { $0.id == incomingMessage.id })
            guard !isDuplicate else { return }

            // If the message sender matches current user, skip (already added optimistically)
            // We check by comparing content + recent timestamp as a secondary guard
            var adjusted = incomingMessage
            if let currentUserId {
                // The realtime payload doesn't carry isFromCurrentUser;
                // compare sender_id from the DTO indirectly via sender name
                if adjusted.senderName == viewModel.currentUser?.fullName {
                    adjusted = ChatMessage(
                        id: incomingMessage.id,
                        senderName: incomingMessage.senderName,
                        content: incomingMessage.content,
                        timestamp: incomingMessage.timestamp,
                        isFromCurrentUser: true
                    )
                    // If optimistic insert already exists with same content, skip
                    let recentDuplicate = viewModel.conversations[convIndex].messages.contains {
                        $0.isFromCurrentUser && $0.content == incomingMessage.content &&
                        abs($0.timestamp.timeIntervalSince(incomingMessage.timestamp)) < 5
                    }
                    if recentDuplicate { return }
                }
            }

            viewModel.conversations[convIndex].messages.append(adjusted)
            viewModel.conversations[convIndex].lastMessage = adjusted.content
            viewModel.conversations[convIndex].lastMessageDate = adjusted.timestamp
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
