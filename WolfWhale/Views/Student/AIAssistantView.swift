import SwiftUI

struct AIAssistantView: View {
    private var service = AIAssistantService.shared
    @State private var inputText = ""
    @State private var hapticTrigger = false
    @State private var clearTrigger = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !service.isAvailable {
                    unavailableView
                } else {
                    chatArea
                    inputBar
                }
            }
            .background { HolographicBackground() }
            .navigationTitle("Study Assistant")
            .toolbar {
                if service.isAvailable {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            clearTrigger.toggle()
                            service.clearHistory()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: clearTrigger)
                        .accessibilityLabel("Reset conversation")
                    }
                }
            }
            .onAppear {
                if service.messages.isEmpty {
                    service.startNewSession()
                }
            }
        }
    }

    // MARK: - Unavailable View

    private var unavailableView: some View {
        ContentUnavailableView {
            Label("On-Device AI Unavailable", systemImage: "apple.intelligence")
        } description: {
            Text("This device does not support on-device AI. A compatible device with Apple Intelligence is required to use the Study Assistant.")
        }
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if service.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(service.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }

                    if service.isProcessing {
                        typingIndicator
                            .id("typing")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .onChange(of: service.messages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastMessage = service.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: service.isProcessing) {
                if service.isProcessing {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.breathe, options: .repeat(.periodic(delay: 2)))

            Text("AI Study Assistant")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text("Ask me anything about your studies!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                suggestionChip("Explain photosynthesis simply")
                suggestionChip("Quiz me on fractions")
                suggestionChip("Give me study tips for exams")
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: AIAssistantService.AIMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 48)
            } else {
                // AI avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if !message.isUser {
                    Text("AI")
                        .font(.caption2.bold())
                        .foregroundStyle(.purple)
                        .padding(.leading, 4)
                }

                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(12)
                    .background {
                        if message.isUser {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.accentColor)
                        }
                    }
                    .if(!message.isUser) { view in
                        view.glassCard(cornerRadius: 16)
                    }
                    .foregroundStyle(message.isUser ? .white : .primary)

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !message.isUser {
                Spacer(minLength: 48)
            }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(service.isProcessing ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: service.isProcessing
                        )
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16)

            Spacer(minLength: 48)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask a question...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .padding(12)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }

            Button {
                hapticTrigger.toggle()
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary
                            : Color.accentColor
                    )
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isProcessing)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 0))
    }

    // MARK: - Helpers

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task {
            await service.sendMessage(text)
        }
    }
}

// MARK: - Conditional Modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
