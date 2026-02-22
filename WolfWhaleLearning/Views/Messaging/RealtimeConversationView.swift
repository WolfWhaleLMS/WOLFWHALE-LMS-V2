import SwiftUI

struct RealtimeConversationView: View {
    let conversation: Conversation
    @Bindable var viewModel: AppViewModel

    @State private var chatService = ChatRealtimeService()
    @State private var messageText = ""
    @State private var sendTrigger = false
    @State private var retryMessageId: UUID?
    @FocusState private var isTextFieldFocused: Bool

    // MARK: - Derived State

    private var messages: [ChatMessage] {
        viewModel.conversations.first(where: { $0.id == conversation.id })?.messages ?? conversation.messages
    }

    private var typingText: String? {
        let names = Array(chatService.typingUsers.values)
        guard !names.isEmpty else { return nil }
        if names.count == 1 {
            return "\(names[0]) is typing"
        } else {
            return "\(names[0]) and \(names.count - 1) other\(names.count > 2 ? "s" : "") are typing"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            if let typingText {
                typingIndicator(typingText)
            }

            inputBar
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                connectionIndicator
            }
        }
        .task {
            await subscribeToRealtime()
        }
        .onDisappear {
            Task {
                await chatService.unsubscribeFromConversation(conversation.id)
            }
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
                                timestampLabel(for: message.timestamp, at: index)
                            }
                            messageBubble(message, isLast: index == messages.count - 1)
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

    private func messageBubble(_ message: ChatMessage, isLast: Bool) -> some View {
        HStack(alignment: .bottom) {
            if message.isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                HStack(spacing: 6) {
                    if message.status == .failed && message.isFromCurrentUser {
                        retryButton(for: message)
                    }

                    Text(message.content)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                        .background(
                            message.isFromCurrentUser
                                ? AnyShapeStyle(.indigo)
                                : AnyShapeStyle(Color(UIColor.tertiarySystemFill)),
                            in: .rect(
                                topLeadingRadius: 16,
                                bottomLeadingRadius: message.isFromCurrentUser ? 16 : 4,
                                bottomTrailingRadius: message.isFromCurrentUser ? 4 : 16,
                                topTrailingRadius: 16
                            )
                        )
                        .glassEffect(
                            message.isFromCurrentUser ? .regular.tint(.indigo) : .identity,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .opacity(message.status == .sending ? 0.7 : 1.0)
                }

                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if message.isFromCurrentUser {
                        statusIndicator(for: message.status)
                    }

                    // Read receipt on last outgoing message
                    if isLast && message.isFromCurrentUser && message.status == .read {
                        Text("Read")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !message.isFromCurrentUser { Spacer(minLength: 60) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: message))
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private func statusIndicator(for status: MessageStatus) -> some View {
        switch status {
        case .sending:
            ProgressView()
                .controlSize(.mini)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .delivered:
            Image(systemName: "checkmark.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .read:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.indigo)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Retry Button

    private func retryButton(for message: ChatMessage) -> some View {
        Button {
            retryMessageId = message.id
            retrySend(message)
        } label: {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.title3)
                .foregroundStyle(.red)
        }
        .accessibilityLabel("Retry sending message")
        .accessibilityHint("Double tap to resend this message")
    }

    // MARK: - Timestamp Labels

    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index].timestamp
        let previous = messages[index - 1].timestamp

        // Show on date change.
        if !Calendar.current.isDate(current, inSameDayAs: previous) {
            return true
        }

        // Show every 15 minutes.
        return current.timeIntervalSince(previous) > 900
    }

    private func timestampLabel(for date: Date, at index: Int) -> some View {
        Group {
            if index > 0 && !Calendar.current.isDate(date, inSameDayAs: messages[index - 1].timestamp) {
                Text(date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            } else {
                Text(date, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Typing Indicator

    private func typingIndicator(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            TypingDotsView()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: text)
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
                .onChange(of: messageText) { _, newValue in
                    if !newValue.isEmpty {
                        Task {
                            await chatService.sendTypingIndicator(
                                conversationId: conversation.id,
                                userName: viewModel.currentUser?.fullName ?? "You"
                            )
                        }
                    }
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .tint(.indigo)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .sensoryFeedback(.impact(weight: .light), trigger: sendTrigger)
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
            .fill(chatService.isConnected ? .green : .gray)
            .frame(width: 8, height: 8)
            .help(chatService.isConnected ? "Live" : "Connecting...")
            .accessibilityLabel(chatService.isConnected ? "Connected, live updates active" : "Connecting to server")
    }

    // MARK: - Actions

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let content = trimmed
        messageText = ""
        sendTrigger.toggle()

        // Stop typing indicator.
        Task {
            await chatService.stopTypingIndicator(conversationId: conversation.id)
        }

        guard let user = viewModel.currentUser else { return }

        // Optimistic insert: add the message to the local list immediately.
        let optimisticMessage = ChatMessage(
            id: UUID(),
            senderName: user.fullName,
            content: content,
            timestamp: Date(),
            isFromCurrentUser: true,
            status: .sending
        )

        if let index = viewModel.conversations.firstIndex(where: { $0.id == conversation.id }) {
            viewModel.conversations[index].messages.append(optimisticMessage)
            viewModel.conversations[index].lastMessage = content
            viewModel.conversations[index].lastMessageDate = Date()
        }

        // Persist to Supabase.
        Task {
            let result = await chatService.sendMessage(
                conversationId: conversation.id,
                content: content,
                senderId: user.id,
                senderName: user.fullName
            )

            guard let index = viewModel.conversations.firstIndex(where: { $0.id == conversation.id }) else { return }

            // Update the optimistic message status.
            if let msgIndex = viewModel.conversations[index].messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                if let result, result.status == .sent {
                    viewModel.conversations[index].messages[msgIndex].status = .sent
                } else {
                    viewModel.conversations[index].messages[msgIndex].status = .failed
                }
            }
        }
    }

    private func retrySend(_ message: ChatMessage) {
        guard let user = viewModel.currentUser else { return }
        guard let convIndex = viewModel.conversations.firstIndex(where: { $0.id == conversation.id }) else { return }

        // Mark as sending again.
        if let msgIndex = viewModel.conversations[convIndex].messages.firstIndex(where: { $0.id == message.id }) {
            viewModel.conversations[convIndex].messages[msgIndex].status = .sending
        }

        Task {
            let result = await chatService.sendMessage(
                conversationId: conversation.id,
                content: message.content,
                senderId: user.id,
                senderName: user.fullName
            )

            guard let convIdx = viewModel.conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
            if let msgIdx = viewModel.conversations[convIdx].messages.firstIndex(where: { $0.id == message.id }) {
                if let result, result.status == .sent {
                    viewModel.conversations[convIdx].messages[msgIdx].status = .sent
                } else {
                    viewModel.conversations[convIdx].messages[msgIdx].status = .failed
                }
            }
        }
    }

    private func subscribeToRealtime() async {
        let currentUserId = viewModel.currentUser?.id

        await chatService.subscribeToConversation(
            conversation.id,
            currentUserId: currentUserId
        ) { incomingMessage in
            guard let convIndex = viewModel.conversations.firstIndex(where: { $0.id == conversation.id }) else {
                return
            }

            // Avoid duplicate messages by ID.
            let isDuplicate = viewModel.conversations[convIndex].messages.contains(where: { $0.id == incomingMessage.id })
            guard !isDuplicate else { return }

            // If the message is from the current user, check for a recent
            // optimistic duplicate (same content within 5 seconds).
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

        // Mark as read when entering the conversation.
        if let userId = viewModel.currentUser?.id {
            await chatService.markConversationAsRead(conversationId: conversation.id, userId: userId)
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

    // MARK: - Accessibility

    private func accessibilityLabel(for message: ChatMessage) -> String {
        let sender = message.isFromCurrentUser ? "You" : message.senderName
        let time = message.timestamp.formatted(.dateTime.hour().minute())
        var label = "\(sender) said: \(message.content), at \(time)"
        switch message.status {
        case .sending: label += ", sending"
        case .failed: label += ", failed to send"
        case .read: label += ", read"
        default: break
        }
        return label
    }
}

// MARK: - Typing Dots Animation

private struct TypingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 5, height: 5)
                    .offset(y: animating ? yOffset(for: index) : 0)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
            ) {
                animating = true
            }
        }
    }

    private func yOffset(for index: Int) -> CGFloat {
        // Stagger the bounce for each dot.
        switch index {
        case 0: return -4
        case 1: return -3
        case 2: return -2
        default: return 0
        }
    }
}
