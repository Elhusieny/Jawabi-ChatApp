
import Foundation
import SwiftUI

// This is the final class you use in your views
// It inherits ALL functionality from the chain:
// BaseChatViewModel → SignalRConnectionManager → MessageSendingManager → IncomingMessageHandler
class ChatViewModel: IncomingMessageHandler {
    private var refreshTimer: Timer?

    // MARK: - Typing Indicator Properties
    override init(signalRService: any SignalRServiceProtocol = SignalRService()) {
        super.init(signalRService: signalRService)
        setupSignalRHandlers()  // ✅ Call this

        setupAppLifecycleHandlers()
    }
    
    // MARK: - Additional Setup
    
    func startPollingForChat(chatId: Int) {
        currentChatId = chatId
        stopPolling()
        markChatAsRead(chatId: chatId)
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.loadChat(chatId: chatId)
        }
    }
    
    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        currentChatId = nil
    }
    // MARK: - Typing Indicator Methods

    
    private func setupAppLifecycleHandlers() {
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.ensureSignalRConnection()
                self?.refreshChats()
            }
        }
    
      
}
