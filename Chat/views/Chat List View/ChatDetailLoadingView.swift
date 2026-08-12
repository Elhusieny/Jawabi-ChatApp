import SwiftUI

/// Standalone loading wrapper — kept as-is in case other parts of the app
/// (e.g. a deep-link handler) push straight to this rather than going
/// through `ChatListView`'s own `chatDestination(for:)`.
struct ChatDetailLoadingView: View {
    let chatId: Int
    @ObservedObject var chatViewModel: ChatViewModel
    private let primaryColor: Color = .jawabiPrimary

    var body: some View {
        if let chat = chatViewModel.chats.first(where: { $0.id == chatId }) {
            ChatDetailView(chat: chat, chatViewModel: chatViewModel)
        } else {
            ProgressView("Loading chat...")
                .tint(primaryColor)
                .onAppear {
                    chatViewModel.loadChat(chatId: chatId)
                    chatViewModel.fetchAllChatsFromServer()
                }
        }
    }
}