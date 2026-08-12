import Foundation

/// Single responsibility: persist a message that was composed while
/// offline, both into the local chat store (for immediate display)
/// and into UserDefaults (for later re-send / sync).
final class OfflineMessageStore: OfflineMessageStoring {

    private weak var chatStore: ChatStore?
    private let userDefaults: UserDefaults

    init(chatStore: ChatStore, userDefaults: UserDefaults = .standard) {
        self.chatStore = chatStore
        self.userDefaults = userDefaults
    }

    func saveOfflineMessage(_ text: String, chatId: Int) {
        chatStore?.insertOutgoingMessage(chatId: chatId, text: text, type: .text)

        var pendingMessages = userDefaults.dictionary(forKey: "pending_messages") ?? [:]
        let messageId = UUID().uuidString
        pendingMessages[messageId] = [
            "chatId": chatId,
            "text": text,
            "timestamp": Date().timeIntervalSince1970
        ]
        userDefaults.set(pendingMessages, forKey: "pending_messages")
        chatStore?.fetchChatsSync()
    }
}