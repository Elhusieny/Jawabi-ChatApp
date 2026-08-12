import Foundation

/// Single responsibility: decide whether a typed text message goes
/// straight to the server or gets queued offline, and say so.
final class MessageSendingCoordinator {

    private weak var chatStore: ChatStore?
    private let offlineStore: OfflineMessageStoring
    private let alertPresenter: AlertPresenting

    init(chatStore: ChatStore, offlineStore: OfflineMessageStoring, alertPresenter: AlertPresenting) {
        self.chatStore = chatStore
        self.offlineStore = offlineStore
        self.alertPresenter = alertPresenter
    }

    func sendMessage(_ text: String, chatId: Int, isOffline: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isOffline {
            offlineStore.saveOfflineMessage(trimmed, chatId: chatId)
            alertPresenter.showAlert(
                title: "Message Saved",
                message: "Your message will be sent when you're back online."
            )
        } else {
            chatStore?.sendMessage(trimmed, chatId: chatId)
        }
    }
}