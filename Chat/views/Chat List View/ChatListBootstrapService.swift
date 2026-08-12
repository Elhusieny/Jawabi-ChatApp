import Foundation

/// Single responsibility: run the "list just appeared" startup sequence.
/// This used to be ~15 lines inlined into `.onAppear`, mixing db cleanup,
/// network calls, and view-model syncing. Now it's one call, and the
/// sequence itself is unit-testable in isolation from SwiftUI.
final class ChatListBootstrapService: ChatListBootstrapping {

    func bootstrap(chatStore: ChatStore, chatViewModel: ChatViewModel, isOffline: Bool) {
        chatStore.cleanupDatabaseOnLaunch()
        chatStore.refreshChatsFromServer()
        chatViewModel.loadAllUsers()
        chatViewModel.connectSignalR()
        chatStore.loadInitialData()

        if !isOffline {
            chatStore.refreshChatsFromServer()
            chatViewModel.connectSignalR()
        }

        chatViewModel.syncChatsFromStore(chatStore.chats)
    }
}