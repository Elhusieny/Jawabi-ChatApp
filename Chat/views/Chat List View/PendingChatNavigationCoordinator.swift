import Foundation

/// Single responsibility: given a chat id that arrived via push
/// notification, wait for it to exist in the (SwiftData-backed) chat
/// store and then fire a navigation callback — retrying once after a
/// server refresh if it isn't there yet. Previously this retry/backoff
/// logic was inlined in `ChatListView.onAppear`.
final class PendingChatNavigationCoordinator: PendingChatNavigating {

    func resolvePendingNavigation(
        chatId: Int,
        chatStore: ChatStore,
        navigate: @escaping (Int) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if chatStore.chats.contains(where: { $0.chatId == chatId }) {
                navigate(chatId)
                return
            }

            chatStore.refreshChatsFromServer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if chatStore.chats.contains(where: { $0.chatId == chatId }) {
                    navigate(chatId)
                }
            }
        }
    }
}