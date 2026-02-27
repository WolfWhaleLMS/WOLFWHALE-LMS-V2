import Foundation
import Supabase
import Realtime

@Observable
@MainActor
final class ChatRealtimeService {

    // MARK: - Public State

    var error: String?
    var isLoading = false

    /// Users currently typing in each conversation: userId -> display name
    var typingUsers: [UUID: String] = [:]

    /// Unread message counts per conversation
    var unreadCounts: [UUID: Int] = [:]

    /// Whether the primary conversation channel is connected.
    private(set) var isConnected = false

    // MARK: - Private State

    /// Maximum number of active channels to prevent unbounded memory growth.
    private let maxActiveChannels = 10

    /// Active Supabase Realtime channels keyed by conversation ID string.
    private var activeChannels: [String: RealtimeChannelV2] = [:]

    /// Active listener tasks keyed by conversation ID string.
    private var listenTasks: [String: Task<Void, Never>] = [:]

    /// In-memory sender name cache to avoid redundant profile lookups.
    private var senderNameCache: [UUID: String] = [:]

    /// Typing indicator debounce tasks keyed by conversation ID string.
    private var typingDebounce: [String: Task<Void, Never>] = [:]

    /// Task running the infinite network-observer loop so it can be cancelled on cleanup.
    private var networkObserverTask: Task<Void, Never>?

    /// Network monitor used for auto-reconnection after connectivity loss.
    private let networkMonitor = NetworkMonitor()

    /// The conversation ID of the most recent single-conversation subscription.
    private var currentConversationId: UUID?

    /// The message handler of the most recent single-conversation subscription.
    private var currentMessageHandler: ((ChatMessage) -> Void)?

    // MARK: - Date Parsing

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func parseDate(_ str: String?) -> Date {
        guard let str else { return Date() }
        return iso8601.date(from: str) ?? dateFormatter.date(from: str) ?? Date()
    }

    // MARK: - Subscribe to a Single Conversation

    /// Subscribes to INSERT events on the `messages` table filtered by
    /// `conversation_id` and delivers decoded `ChatMessage` values via the
    /// provided callback. Also subscribes to a broadcast channel for typing
    /// indicators.
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to listen to.
    ///   - currentUserId: The logged-in user's ID, used to set `isFromCurrentUser`.
    ///   - onNewMessage: Callback invoked on the main actor for every new message.
    func subscribeToConversation(
        _ conversationId: UUID,
        currentUserId: UUID? = nil,
        onNewMessage: @escaping @MainActor (ChatMessage) -> Void
    ) async {
        // Store for reconnection.
        currentConversationId = conversationId
        currentMessageHandler = onNewMessage

        let key = conversationId.uuidString

        // Tear down any existing subscription for this conversation.
        await unsubscribeFromConversation(conversationId)

        let ch = supabaseClient.realtimeV2.channel("chat:\(key)")

        let insertions = ch.postgresChange(
            InsertAction.self,
            table: "messages",
            filter: .eq("conversation_id", value: key)
        )

        let listenTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await ch.subscribeWithError()
                await MainActor.run {
                    self.isConnected = true
                }
            } catch {
                await MainActor.run {
                    self.isConnected = false
                    self.error = "Failed to connect to realtime: \(UserFacingError.message(from: error))"
                }
                #if DEBUG
                print("[ChatRealtimeService] subscription failed: \(error)")
                #endif
                return
            }

            for await action in insertions {
                guard !Task.isCancelled else { break }
                do {
                    let dto = try action.decodeRecord(as: MessageDTO.self, decoder: JSONDecoder())
                    let senderName = await self.resolveSenderName(for: dto.senderId)
                    let isFromCurrentUser = currentUserId.map { dto.senderId == $0 } ?? false

                    let chatMessage = ChatMessage(
                        id: dto.id,
                        senderName: senderName,
                        content: dto.content,
                        timestamp: self.parseDate(dto.createdAt),
                        isFromCurrentUser: isFromCurrentUser,
                        status: .delivered
                    )
                    await MainActor.run {
                        onNewMessage(chatMessage)
                    }
                } catch {
                    #if DEBUG
                    print("[ChatRealtimeService] Failed to decode message: \(error)")
                    #endif
                }
            }
        }

        // Evict the oldest channel if at capacity to prevent unbounded growth.
        if activeChannels.count >= maxActiveChannels {
            if let oldestKey = activeChannels.keys.first {
                let channel = activeChannels.removeValue(forKey: oldestKey)
                listenTasks[oldestKey]?.cancel()
                listenTasks.removeValue(forKey: oldestKey)
                if let channel {
                    await supabaseClient.realtimeV2.removeChannel(channel)
                }
            }
        }

        activeChannels[key] = ch
        listenTasks[key] = listenTask

        // Subscribe to a broadcast channel for typing indicators.
        await subscribeToTypingBroadcast(conversationId: conversationId)
    }

    // MARK: - Subscribe to All Conversations

    /// Subscribes to message INSERT events across multiple conversations so
    /// the messages list can show last-message previews in real time.
    ///
    /// - Parameters:
    ///   - userConversationIds: The conversation IDs the user participates in.
    ///   - currentUserId: The logged-in user's ID.
    ///   - onUpdate: Callback with the conversation ID and the new message.
    func subscribeToAllConversations(
        userConversationIds: [UUID],
        currentUserId: UUID? = nil,
        onUpdate: @escaping @MainActor (UUID, ChatMessage) -> Void
    ) async {
        for conversationId in userConversationIds {
            let key = "all:\(conversationId.uuidString)"

            // Skip if already subscribed.
            guard activeChannels[key] == nil else { continue }

            let ch = supabaseClient.realtimeV2.channel(key)

            let insertions = ch.postgresChange(
                InsertAction.self,
                table: "messages",
                filter: .eq("conversation_id", value: conversationId.uuidString)
            )

            let listenTask = Task { [weak self] in
                guard let self else { return }

                do {
                    try await ch.subscribeWithError()
                } catch {
                    #if DEBUG
                    print("[ChatRealtimeService] all-conversations subscription failed for \(conversationId): \(error)")
                    #endif
                    return
                }

                for await action in insertions {
                    guard !Task.isCancelled else { break }
                    do {
                        let dto = try action.decodeRecord(as: MessageDTO.self, decoder: JSONDecoder())
                        let senderName = await self.resolveSenderName(for: dto.senderId)
                        let isFromCurrentUser = currentUserId.map { dto.senderId == $0 } ?? false

                        let chatMessage = ChatMessage(
                            id: dto.id,
                            senderName: senderName,
                            content: dto.content,
                            timestamp: self.parseDate(dto.createdAt),
                            isFromCurrentUser: isFromCurrentUser,
                            status: .delivered
                        )
                        await MainActor.run {
                            onUpdate(conversationId, chatMessage)
                        }
                    } catch {
                        #if DEBUG
                        print("[ChatRealtimeService] Failed to decode message in all-conversations: \(error)")
                        #endif
                    }
                }
            }

            activeChannels[key] = ch
            listenTasks[key] = listenTask
        }
    }

    // MARK: - Typing Indicators

    /// Sends a typing indicator broadcast for the given conversation.
    func sendTypingIndicator(conversationId: UUID, userName: String) async {
        let key = conversationId.uuidString
        let broadcastKey = "typing:\(key)"

        guard let ch = activeChannels[key] ?? activeChannels[broadcastKey] else { return }

        let payload: [String: AnyJSON] = [
            "userName": .string(userName),
            "isTyping": .bool(true)
        ]
        await ch.broadcast(event: "typing", message: payload)

        // Auto-clear after 3 seconds if no further keystrokes.
        typingDebounce[key]?.cancel()
        typingDebounce[key] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await self?.stopTypingIndicator(conversationId: conversationId)
        }
    }

    /// Clears the typing indicator for the given conversation.
    func stopTypingIndicator(conversationId: UUID) async {
        let key = conversationId.uuidString
        let broadcastKey = "typing:\(key)"
        typingDebounce[key]?.cancel()
        typingDebounce.removeValue(forKey: key)

        guard let ch = activeChannels[key] ?? activeChannels[broadcastKey] else { return }

        let payload: [String: AnyJSON] = [
            "isTyping": .bool(false)
        ]
        await ch.broadcast(event: "typing", message: payload)

        typingUsers.removeAll()
    }

    /// Subscribes to the typing broadcast channel for a conversation.
    private func subscribeToTypingBroadcast(conversationId: UUID) async {
        let key = conversationId.uuidString
        let broadcastKey = "typing:\(key)"

        // Re-use the main channel for broadcast events if already active.
        guard let ch = activeChannels[key] else { return }

        let broadcastStream = ch.broadcastStream(event: "typing")

        let task = Task { [weak self] in
            for await message in broadcastStream {
                guard !Task.isCancelled, let self else { break }
                // The broadcast stream yields the raw JSONObject that was
                // passed to `broadcast(event:message:)`. The keys are at the
                // top level.
                let isTyping = message["isTyping"]?.boolValue ?? false
                let userName = message["userName"]?.stringValue ?? "Someone"

                await MainActor.run {
                    if isTyping {
                        // Use a deterministic pseudo UUID so the same user
                        // only occupies one slot in the dictionary.
                        let pseudoId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
                        self.typingUsers[pseudoId] = userName
                    } else {
                        self.typingUsers.removeAll()
                    }
                }
            }
        }

        listenTasks[broadcastKey] = task
    }

    // MARK: - Read Receipts

    /// Marks a conversation as read for the given user by resetting the
    /// local unread count. A server-side update can be added here later.
    func markConversationAsRead(conversationId: UUID, userId: UUID) async {
        unreadCounts[conversationId] = 0

        // Optionally update a server-side read_receipts table:
        // do {
        //     try await supabaseClient
        //         .from("read_receipts")
        //         .upsert(["conversation_id": conversationId.uuidString,
        //                   "user_id": userId.uuidString,
        //                   "read_at": ISO8601DateFormatter().string(from: Date())])
        //         .execute()
        // } catch { }
    }

    // MARK: - Send Message with Optimistic UI

    /// Sends a message to the server and returns an optimistic `ChatMessage`
    /// immediately. The returned message has `.sending` status. The caller
    /// should update the status to `.sent` once the server acknowledges, or
    /// `.failed` on error.
    func sendMessage(
        conversationId: UUID,
        content: String,
        senderId: UUID,
        senderName: String
    ) async -> ChatMessage? {
        let optimisticId = UUID()
        let optimisticMessage = ChatMessage(
            id: optimisticId,
            senderName: senderName,
            content: content,
            timestamp: Date(),
            isFromCurrentUser: true,
            status: .sending
        )

        // Persist to Supabase.
        let dto = InsertMessageDTO(
            tenantId: nil,
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            attachments: nil
        )

        do {
            try await supabaseClient
                .from("messages")
                .insert(dto)
                .execute()
            // The realtime subscription will deliver the canonical message.
            // Return the optimistic message so the caller can show it
            // immediately and reconcile later.
            var sent = optimisticMessage
            sent.status = .sent
            return sent
        } catch {
            self.error = "Failed to send message: \(UserFacingError.message(from: error))"
            #if DEBUG
            print("[ChatRealtimeService] sendMessage failed: \(error)")
            #endif
            var failed = optimisticMessage
            failed.status = .failed
            return failed
        }
    }

    // MARK: - Unsubscribe

    /// Unsubscribes from a specific conversation channel and its typing
    /// broadcast.
    func unsubscribeFromConversation(_ conversationId: UUID) async {
        let key = conversationId.uuidString
        let broadcastKey = "typing:\(key)"

        // Cancel listener tasks.
        listenTasks[key]?.cancel()
        listenTasks.removeValue(forKey: key)
        listenTasks[broadcastKey]?.cancel()
        listenTasks.removeValue(forKey: broadcastKey)

        // Cancel typing debounce.
        typingDebounce[key]?.cancel()
        typingDebounce.removeValue(forKey: key)

        // Remove channels.
        if let ch = activeChannels.removeValue(forKey: key) {
            await supabaseClient.realtimeV2.removeChannel(ch)
        }
        if let ch = activeChannels.removeValue(forKey: broadcastKey) {
            await supabaseClient.realtimeV2.removeChannel(ch)
        }

        // Reset connection state if no channels remain.
        if activeChannels.isEmpty {
            isConnected = false
        }

        typingUsers.removeAll()
    }

    /// Tears down all active subscriptions.
    func unsubscribeFromAll() async {
        networkObserverTask?.cancel()
        networkObserverTask = nil

        for (_, task) in listenTasks {
            task.cancel()
        }
        listenTasks.removeAll()

        for (_, task) in typingDebounce {
            task.cancel()
        }
        typingDebounce.removeAll()

        for (_, ch) in activeChannels {
            await supabaseClient.realtimeV2.removeChannel(ch)
        }
        activeChannels.removeAll()

        isConnected = false
        typingUsers.removeAll()
        error = nil
    }

    // MARK: - Reconnection

    /// Reconnects to the current conversation channel after network recovery.
    func reconnect() async {
        guard let conversationId = currentConversationId else { return }
        #if DEBUG
        print("[ChatRealtimeService] Reconnecting to conversation \(conversationId)")
        #endif
        await unsubscribeFromConversation(conversationId)
        try? await Task.sleep(for: .seconds(1))
        await subscribeToConversation(conversationId, onNewMessage: currentMessageHandler ?? { _ in })
    }

    /// Starts observing network connectivity changes for auto-reconnection.
    /// Cancels any previously running observer to prevent accumulation.
    func startNetworkObserver() {
        networkObserverTask?.cancel()
        networkObserverTask = Task {
            var wasOffline = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                let isOnline = networkMonitor.isConnected
                if wasOffline && isOnline {
                    await reconnect()
                }
                wasOffline = !isOnline
            }
        }
    }

    // MARK: - Helpers

    /// Resolves a sender display name from the profiles table, caching the
    /// result so each sender is only queried once.
    private func resolveSenderName(for senderId: UUID) async -> String {
        if let cached = senderNameCache[senderId] {
            return cached
        }

        do {
            let profiles: [ProfileDTO] = try await supabaseClient
                .from("profiles")
                .select("id, first_name, last_name")
                .eq("id", value: senderId.uuidString)
                .limit(1)
                .execute()
                .value

            if let profile = profiles.first {
                let name = "\(profile.firstName ?? "") \(profile.lastName ?? "")".trimmingCharacters(in: .whitespaces)
                let displayName = name.isEmpty ? "Unknown" : name
                senderNameCache[senderId] = displayName
                return displayName
            }
        } catch {
            #if DEBUG
            print("[ChatRealtimeService] Failed to resolve sender name for \(senderId): \(error)")
            #endif
        }

        let fallback = "User"
        senderNameCache[senderId] = fallback
        return fallback
    }
}
