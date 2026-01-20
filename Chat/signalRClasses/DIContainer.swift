
import Foundation

class DIContainer {
    static let shared = DIContainer()
    
    let signalRService: SignalRServiceProtocol
    let chatViewModel: ChatViewModel
    
    private init() {
        self.signalRService = SignalRService()
        self.chatViewModel = ChatViewModel(signalRService: signalRService)
    }
    
    // Call this when user logs in
    func initializeSignalR() {
        signalRService.connect()
    }
    
    // Call this when user logs out
    func cleanup() {
        signalRService.disconnect()
//        chatViewModel.clearUserChats()
    }
}
