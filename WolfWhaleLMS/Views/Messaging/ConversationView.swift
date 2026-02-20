import SwiftUI

struct ConversationView: View {
    let conversation: Conversation
    @Bindable var viewModel: AppViewModel
    @State private var messageText = ""
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

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !message.isFromCurrentUser { Spacer(minLength: 60) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message...", text: $messageText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemFill), in: Capsule())
                .focused($isTextFieldFocused)

            Button {
                guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                viewModel.sendMessage(in: conversation.id, text: messageText)
                messageText = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .sensoryFeedback(.impact(weight: .light), trigger: messages.count)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
