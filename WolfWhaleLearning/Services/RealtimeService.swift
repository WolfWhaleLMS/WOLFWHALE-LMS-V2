import Foundation
import Supabase
import Realtime

@Observable
@MainActor
final class RealtimeService {

    // MARK: - State

    private(set) var isConnected = false
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?

    /// In-memory cache of sender ID -> display name.
    /// Populated by profile lookups so we only fetch each sender once.
    private var senderNameCache: [UUID: String] = [:]

    // Shared ISO 8601 formatter matching the rest of the app
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

    // MARK: - Public API

    /// Subscribes to INSERT events on the `messages` table filtered by `conversation_id`.
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to listen on.
    ///   - currentUserId: The logged-in user's ID, used to set `isFromCurrentUser`.
    ///   - onMessage: Callback invoked on the main actor for every new message.
    func subscribeToConversation(
        _ conversationId: UUID,
        currentUserId: UUID?,
        onMessage: @escaping @MainActor (ChatMessage) -> Void
    ) {
        // Tear down any previous subscription first
        unsubscribe()

        let ch = supabaseClient.realtimeV2.channel("messages:\(conversationId.uuidString)")

        let insertions = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversationId.uuidString)"
        )

        listenTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await ch.subscribeWithError()
                await MainActor.run { self.isConnected = true }
            } catch {
                await MainActor.run { self.isConnected = false }
                return
            }

            for await action in insertions {
                do {
                    let dto = try action.decodeRecord(as: MessageDTO.self, decoder: JSONDecoder())

                    // Resolve sender name from cache or by querying profiles
                    let senderName = await self.resolveSenderName(for: dto.senderId)

                    let isFromCurrentUser = currentUserId != nil && dto.senderId == currentUserId

                    let chatMessage = ChatMessage(
                        id: dto.id,
                        senderName: senderName,
                        content: dto.content,
                        timestamp: self.parseDate(dto.createdAt),
                        isFromCurrentUser: isFromCurrentUser
                    )
                    await MainActor.run {
                        onMessage(chatMessage)
                    }
                } catch {
                    // Silently skip malformed payloads to keep the stream alive
                    #if DEBUG
                    print("[RealtimeService] Failed to decode message: \(error)")
                    #endif
                }
            }
        }

        self.channel = ch
    }

    /// Backwards-compatible overload without `currentUserId`.
    func subscribeToConversation(
        _ conversationId: UUID,
        onMessage: @escaping @MainActor (ChatMessage) -> Void
    ) {
        subscribeToConversation(conversationId, currentUserId: nil, onMessage: onMessage)
    }

    /// Tears down the current channel subscription and cancels the listener task.
    func unsubscribe() {
        listenTask?.cancel()
        listenTask = nil

        if let channel {
            Task {
                await supabaseClient.realtimeV2.removeChannel(channel)
            }
        }

        channel = nil
        isConnected = false
    }

    // MARK: - Helpers

    /// Resolves a sender's display name by looking up the profiles table.
    /// Results are cached so each sender is only queried once per session.
    private func resolveSenderName(for senderId: UUID) async -> String {
        // Check cache first
        if let cached = senderNameCache[senderId] {
            return cached
        }

        // Query the profiles table for this sender
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
            print("[RealtimeService] Failed to resolve sender name for \(senderId): \(error)")
            #endif
        }

        // Fallback
        let fallback = "User"
        senderNameCache[senderId] = fallback
        return fallback
    }

    private func parseDate(_ str: String?) -> Date {
        guard let str else { return Date() }
        return iso8601.date(from: str) ?? dateFormatter.date(from: str) ?? Date()
    }
}
