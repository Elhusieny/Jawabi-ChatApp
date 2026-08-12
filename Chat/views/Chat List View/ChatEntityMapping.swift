import Foundation

// MARK: - 1. Turning a persisted ChatEntity into the view-facing Chat model

protocol ChatEntityMapping {
    func map(_ entity: ChatEntity, using chatStore: ChatStore) -> Chat
}

// MARK: - 2. The "what has to happen when the list first appears" sequence
// (db cleanup, server refresh, load users, connect SignalR, initial load, sync)

protocol ChatListBootstrapping {
    func bootstrap(chatStore: ChatStore, chatViewModel: ChatViewModel, isOffline: Bool)
}

// MARK: - 3. Resolving a chat id that arrived via push notification into
// an actual navigation, retrying once if the chat hasn't synced down yet

protocol PendingChatNavigating {
    func resolvePendingNavigation(
        chatId: Int,
        chatStore: ChatStore,
        navigate: @escaping (Int) -> Void
    )
}

// MARK: - 4. Logging out: remembering the username for quick relogin, then
// actually signing out. Kept separate from the confirmation-dialog UI.

protocol AuthSessionLogoutHandling {
    func logout(currentUsername: String?, authViewModel: AuthViewModel)
}