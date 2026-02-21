import Foundation

nonisolated struct Conversation: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var participantNames: [String]
    var title: String
    var lastMessage: String
    var lastMessageDate: Date
    var unreadCount: Int
    var messages: [ChatMessage]
    var avatarSystemName: String
}

nonisolated struct ChatMessage: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var senderName: String
    var content: String
    var timestamp: Date
    var isFromCurrentUser: Bool
}
