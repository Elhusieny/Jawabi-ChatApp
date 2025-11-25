

import Foundation
import SignalRClient

protocol SignalRServiceProtocol {
    func connect()
    func disconnect()
    func sendMessage(_ message: String, chatId: Int)
    func joinChat(chatId: Int)
    func leaveChat(chatId: Int)
}

class SignalRService: SignalRServiceProtocol, ObservableObject {
    private var connection: HubConnection
    private var connectionDelegate: ConnectionDelegate?
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var receivedMessage: ReceivedMessage?
    @Published var typingUsers: [String] = []
    
    enum ConnectionState {
        case connected, disconnected, connecting, reconnecting
    }
    
    init() {
        // Get token from UserDefaults
        let token = UserDefaults.standard.string(forKey: "authToken") ?? ""
        let baseUrl = "http://158.220.90.131:8444"
        let urlString = "\(baseUrl)/ChatHub?access_token=\(token)"
        
        guard let url = URL(string: urlString) else {
            fatalError("Invalid SignalR URL")
        }
        
        connection = HubConnectionBuilder(url: url)
            .withLogging(minLogLevel: .error)
            .build()
        
        setupHandlers()
        setupConnectionDelegate()
    }
    
    private func setupHandlers() {
        // Handle incoming messages - match your backend method name
        connection.on(method: "ReceiveMessage") { [weak self] (message: ReceivedMessage) in
            DispatchQueue.main.async {
                print("📥 SignalR received message: \(message.text) from \(message.name)")
                self?.receivedMessage = message
            }
        }
        
        // Handle user typing notifications
        connection.on(method: "UserTyping") { [weak self] (userInfo: TypingInfo) in
            DispatchQueue.main.async {
                self?.handleTypingUser(userInfo)
            }
        }
        
        // Handle user stopped typing
        connection.on(method: "UserStoppedTyping") { [weak self] (userId: String) in
            DispatchQueue.main.async {
                self?.removeTypingUser(userId)
            }
        }
    }
    
    private func setupConnectionDelegate() {
        connectionDelegate = ConnectionDelegate { [weak self] in
            DispatchQueue.main.async {
                self?.connectionState = .connected
                print("✅ SignalR connected successfully")
            }
        } connectionDidFail: { [weak self] error in
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                print("❌ SignalR connection failed: \(error)")
            }
        } connectionDidClose: { [weak self] error in
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                print("🔌 SignalR connection closed")
            }
        }
        
        connection.delegate = connectionDelegate
    }
    
    func connect() {
        guard connectionState != .connected && connectionState != .connecting else { return }
        
        connectionState = .connecting
        print("🔗 Connecting to SignalR...")
        connection.start()
    }
    
    func disconnect() {
        connection.stop()
        connectionState = .disconnected
        print("🔌 Disconnected from SignalR")
    }
    
    func sendMessage(_ message: String, chatId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot send message - SignalR not connected")
            return
        }
        
        print("📤 SignalR sending message: '\(message)' to chat \(chatId)")
        
        connection.invoke(method: "SendMessage", message, chatId) { error in
            if let error = error {
                print("❌ Error sending message via SignalR: \(error)")
            } else {
                print("✅ Message sent via SignalR")
            }
        }
    }
    
    func joinChat(chatId: Int) {
        guard connectionState == .connected else { return }
        
        connection.invoke(method: "JoinChat", chatId) { error in
            if let error = error {
                print("❌ Error joining chat: \(error)")
            } else {
                print("✅ Joined chat \(chatId) via SignalR")
            }
        }
    }
    
    func leaveChat(chatId: Int) {
        guard connectionState == .connected else { return }
        
        connection.invoke(method: "LeaveChat", chatId) { error in
            if let error = error {
                print("❌ Error leaving chat: \(error)")
            } else {
                print("✅ Left chat \(chatId) via SignalR")
            }
        }
    }
    
    func sendTyping(chatId: Int) {
        guard connectionState == .connected else { return }
        
        connection.invoke(method: "Typing", chatId) { error in
            if let error = error {
                print("❌ Error sending typing: \(error)")
            }
        }
    }
    
    func sendStopTyping(chatId: Int) {
        guard connectionState == .connected else { return }
        
        connection.invoke(method: "StopTyping", chatId) { error in
            if let error = error {
                print("❌ Error sending stop typing: \(error)")
            }
        }
    }
    
    private func handleTypingUser(_ typingInfo: TypingInfo) {
        if !typingUsers.contains(typingInfo.userName) {
            typingUsers.append(typingInfo.userName)
        }
    }
    
    private func removeTypingUser(_ userId: String) {
        typingUsers.removeAll { $0 == userId }
    }
}

// Connection Delegate
private class ConnectionDelegate: HubConnectionDelegate {
    private let connectionDidOpen: () -> Void
    private let connectionDidFail: (Error) -> Void
    private let connectionDidClose: (Error?) -> Void
    
    init(connectionDidOpen: @escaping () -> Void,
         connectionDidFail: @escaping (Error) -> Void,
         connectionDidClose: @escaping (Error?) -> Void) {
        self.connectionDidOpen = connectionDidOpen
        self.connectionDidFail = connectionDidFail
        self.connectionDidClose = connectionDidClose
    }
    
    func connectionDidOpen(hubConnection: HubConnection) {
        connectionDidOpen()
    }
    
    func connectionDidFailToOpen(error: Error) {
        connectionDidFail(error)
    }
    
    func connectionDidClose(error: Error?) {
        connectionDidClose(error)
    }
    
    func connectionWillReconnect(error: Error) {
        print("🔁 SignalR will reconnect: \(error)")
    }
    
    func connectionDidReconnect() {
        print("✅ SignalR reconnected successfully")
    }
}
