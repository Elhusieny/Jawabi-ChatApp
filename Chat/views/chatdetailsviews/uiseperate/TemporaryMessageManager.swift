import Foundation

/// Single responsibility: add/update/remove the temporary placeholder
/// message bubble (e.g. "UPLOADING:...", "SCANNING:...") that lives
/// inside `chatViewModel.chats` while an upload is in flight.
///
/// This is the only piece of the old view that reaches into
/// `chatViewModel.chats` and rebuilds `Chat` structs, so all of that
/// mutation logic now lives in one place.
final class TemporaryMessageManager: TemporaryMessageManaging {

    private weak var chatViewModel: ChatViewModel?
    private let currentUserProvider: CurrentUserProviding

    init(chatViewModel: ChatViewModel, currentUserProvider: CurrentUserProviding) {
        self.chatViewModel = chatViewModel
        self.currentUserProvider = currentUserProvider
    }

    func addTemporaryMessage(_ message: Message, chatId: Int) {
        mutateChat(chatId: chatId) { messages in
            messages.append(message)
        }
    }

    func updateTemporaryMessage(_ tempMessageId: Int, chatId: Int, displayText: String) {
        mutateChat(chatId: chatId) { messages in
            guard let index = messages.firstIndex(where: { $0.id == tempMessageId }) else { return }
            messages[index] = Message(
                id: tempMessageId,
                displayText: displayText,
                name: self.currentUserProvider.currentUsername(),
                timestamp: ISO8601DateFormatter.shared.string(from: Date()),
                isRead: false
            )
        }
    }

    func removeTemporaryMessage(_ tempMessageId: Int, chatId: Int) {
        mutateChat(chatId: chatId) { messages in
            messages.removeAll { $0.id == tempMessageId }
        }
    }

    // MARK: - Private

    private func mutateChat(chatId: Int, _ mutation: (inout [Message]) -> Void) {
        guard let chatViewModel = chatViewModel,
              let index = chatViewModel.chats.firstIndex(where: { $0.id == chatId }) else { return }

        var updatedChat = chatViewModel.chats[index]
        var messages = updatedChat.messages
        mutation(&messages)

        updatedChat = Chat(
            id: updatedChat.id,
            name: updatedChat.name,
            pictureUrl: updatedChat.pictureUrl,
            type: updatedChat.type,
            messages: messages,
            users: updatedChat.users,
            unreadCount: updatedChat.unreadCount,
            isOnline: updatedChat.isOnline
        )

        chatViewModel.chats[index] = updatedChat
        if chatViewModel.currentChat?.id == chatId {
            chatViewModel.currentChat = updatedChat
        }
        chatViewModel.saveChats()
        chatViewModel.notifyChatsUpdated()
    }
}