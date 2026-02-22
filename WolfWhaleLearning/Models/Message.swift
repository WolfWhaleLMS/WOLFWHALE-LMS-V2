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

nonisolated enum MessageStatus: String, Codable, Sendable {
    case sending, sent, delivered, read, failed
}

nonisolated struct ChatMessage: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var senderName: String
    var content: String
    var timestamp: Date
    var isFromCurrentUser: Bool
    var status: MessageStatus

    init(
        id: UUID,
        senderName: String,
        content: String,
        timestamp: Date,
        isFromCurrentUser: Bool,
        status: MessageStatus = .sent
    ) {
        self.id = id
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.isFromCurrentUser = isFromCurrentUser
        self.status = status
    }

    // Custom Decodable init so existing encoded data without `status` still decodes.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        senderName = try container.decode(String.self, forKey: .senderName)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isFromCurrentUser = try container.decode(Bool.self, forKey: .isFromCurrentUser)
        status = try container.decodeIfPresent(MessageStatus.self, forKey: .status) ?? .sent
    }

    private enum CodingKeys: String, CodingKey {
        case id, senderName, content, timestamp, isFromCurrentUser, status
    }
}
