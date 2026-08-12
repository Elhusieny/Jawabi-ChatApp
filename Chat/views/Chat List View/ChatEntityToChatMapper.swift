import Foundation

/// Single responsibility: convert a `ChatEntity` (SwiftData row) plus its
/// messages into the `Chat` model the UI layer works with. Previously this
/// lived as a private method on `ChatListView` (`convertToChat`); pulling it
/// out means the row-tap navigation path and the notification-driven
/// navigation path can now share exactly the same conversion logic instead
/// of each view/destination closure re-implementing it slightly differently.
final class ChatEntityToChatMapper: ChatEntityMapping {

    func map(_ entity: ChatEntity, using chatStore: ChatStore) -> Chat {
        let messages = chatStore.messages(for: entity.chatId)
            .filter { !$0.isDeleted && $0.messageId != 0 }
            .sorted { $0.timestamp < $1.timestamp }
            .map { msgEntity in
                Message(
                    id: msgEntity.messageId,
                    displayText: msgEntity.text,
                    name: msgEntity.fromDisplayName,
                    timestamp: ISO8601DateFormatter.shared.string(from: msgEntity.timestamp),
                    fileUrl: msgEntity.fileUrl,
                    type: msgEntity.messageType,
                    isFile: msgEntity.fileUrl != nil,
                    fileName: msgEntity.fileName,
                    fileSize: msgEntity.fileSize,
                    fileExtension: msgEntity.fileExtension,
                    isSafe: msgEntity.isSafe,
                    isRead: msgEntity.isSeen
                )
            }

        let users = entity.participants.map { user in
            ChatUser(userId: user.userId, role: 1)
        }

        return Chat(
            id: entity.chatId,
            name: entity.title,
            pictureUrl: entity.avatarUrl ?? "",
            type: entity.isGroup ? 0 : 1,
            messages: messages,
            users: users,
            unreadCount: entity.unreadCount,
            isOnline: entity.participants.first?.isOnline ?? false
        )
    }
}