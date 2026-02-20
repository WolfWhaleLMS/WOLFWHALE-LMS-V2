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
    /// The `onMessage` callback is invoked on the main actor for every new message.
    func subscribeToConversation(
        _ conversationId: UUID,
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

            await ch.subscribe()

            await MainActor.run {
                self.isConnected = true
            }

            for await action in insertions {
                do {
                    let dto = try action.decodeRecord(as: MessageDTO.self, decoder: JSONDecoder())
                    let chatMessage = ChatMessage(
                        id: dto.id,
                        senderName: dto.senderName ?? "Unknown",
                        content: dto.content,
                        timestamp: self.parseDate(dto.createdAt),
                        isFromCurrentUser: false // caller adjusts if needed
                    )
                    await MainActor.run {
                        onMessage(chatMessage)
                    }
                } catch {
                    // Silently skip malformed payloads to keep the stream alive
                    print("[RealtimeService] Failed to decode message: \(error)")
                }
            }
        }

        self.channel = ch
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

    private func parseDate(_ str: String?) -> Date {
        guard let str else { return Date() }
        return iso8601.date(from: str) ?? dateFormatter.date(from: str) ?? Date()
    }
}
