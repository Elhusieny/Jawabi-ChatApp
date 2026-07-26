// MARK: - SwiftDataModels.swift
// Drop this file into your Xcode project.
// Requires iOS 17+ / macOS 14+ (SwiftData).

import Foundation
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// MARK: UserEntity
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a contact / chat participant stored locally.
@Model
final class UserEntity {

    // Stable server-side identifier (userId string from the backend)
    @Attribute(.unique) var userId: String

    var displayName: String
    var avatarUrl: String?
    var isOnline: Bool
    var lastSeen: Date?

    /// All chats this user participates in (inverse of ChatEntity.participants)
    @Relationship(deleteRule: .nullify, inverse: \ChatEntity.participants)
    var chats: [ChatEntity] = []

    init(userId: String,
         displayName: String,
         avatarUrl: String? = nil,
         isOnline: Bool = false,
         lastSeen: Date? = nil) {
        self.userId      = userId
        self.displayName = displayName
        self.avatarUrl   = avatarUrl
        self.isOnline    = isOnline
        self.lastSeen    = lastSeen
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: ChatEntity
// ─────────────────────────────────────────────────────────────────────────────

/// One conversation (private 1-to-1 or group).
@Model
final class ChatEntity {

    /// Server-side chatId
    @Attribute(.unique) var chatId: Int

    var title: String          // display name / group name
    var isGroup: Bool
    var avatarUrl: String?
    var createdAt: Date
    var updatedAt: Date        // updated whenever a new message arrives
    var unreadCount: Int

    /// For group chats, the local user's role ("member" | "admin" | "owner")
    var myRole: String?

    /// Snapshot of the last message text (for chat-list preview)
    var lastMessagePreview: String?
    var lastMessageDate: Date?

    /// All messages in this conversation
    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.chat)
    var messages: [MessageEntity] = []

    /// Participants (many-to-many with UserEntity)
    var participants: [UserEntity] = []

    init(chatId: Int,
         title: String,
         isGroup: Bool = false,
         avatarUrl: String? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now,
         unreadCount: Int = 0) {
        self.chatId      = chatId
        self.title       = title
        self.isGroup     = isGroup
        self.avatarUrl   = avatarUrl
        self.createdAt   = createdAt
        self.updatedAt   = updatedAt
        self.unreadCount = unreadCount
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: MessageEntity
// ─────────────────────────────────────────────────────────────────────────────

/// A single chat message.
@Model
final class MessageEntity {

    /// Server-assigned message id (0 = not yet confirmed by server)
    var messageId: Int

    /// The chat this message belongs to
    var chat: ChatEntity?

    var fromUserId: String      // userId of sender
    var fromDisplayName: String // display name at send time (denormalised for speed)

    var text: String
    var timestamp: Date
    var isOutgoing: Bool        // true = sent by the local user

    // ── File / media attachment ───────────────────────────────────────────
    var rawMessageType: Int     // MessageType.rawValue
    var fileUrl: String?
    var fileName: String?
    var fileSize: Int64
    var fileExtension: String?

    // ── Status flags ──────────────────────────────────────────────────────
    var isSeen: Bool            // seen by the other party
    var isSafe: Bool            // antivirus scan result (true = safe / not yet scanned)
    var isDeleted: Bool

    // Derived helper — avoids importing MessageType everywhere
    var messageType: MessageType {
        MessageType(rawValue: rawMessageType) ?? .text
    }

    init(messageId: Int = 0,
         chat: ChatEntity? = nil,
         fromUserId: String,
         fromDisplayName: String,
         text: String,
         timestamp: Date = .now,
         isOutgoing: Bool,
         rawMessageType: Int = MessageType.text.rawValue,
         fileUrl: String? = nil,
         fileName: String? = nil,
         fileSize: Int64 = 0,
         fileExtension: String? = nil,
         isSeen: Bool = false,
         isSafe: Bool = true,
         isDeleted: Bool = false) {
        self.messageId       = messageId
        self.chat            = chat
        self.fromUserId      = fromUserId
        self.fromDisplayName = fromDisplayName
        self.text            = text
        self.timestamp       = timestamp
        self.isOutgoing      = isOutgoing
        self.rawMessageType  = rawMessageType
        self.fileUrl         = fileUrl
        self.fileName        = fileName
        self.fileSize        = fileSize
        self.fileExtension   = fileExtension
        self.isSeen          = isSeen
        self.isSafe          = isSafe
        self.isDeleted       = isDeleted
    }
}