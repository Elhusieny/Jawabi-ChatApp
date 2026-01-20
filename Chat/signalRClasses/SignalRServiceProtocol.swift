import Foundation
import SignalRClient

import Foundation
import SignalRClient


protocol SignalRServiceProtocol: ObservableObject {
    var connectionState: SignalRService.ConnectionState { get }
    var receivedMessage: ReceivedPrivateMessage? { get }
    var connectionError: String? { get }
    var typingStatus: TypingStatus? { get }
    var userStatus: UserStatus? { get }
    var seenStatus: SeenStatus? { get } // ✅ ADD THIS

    func connect()
    func disconnect()
    func sendMessage(_ message: String, chatId: Int, photoUrl: String?)
    func joinChat(chatId: Int, completion: ((Bool) -> Void)?)
    func leaveChat(chatId: Int)
    func getMessages(chatId: Int)
    func deleteMessage(messageId: Int)
    func sendTypingIndicator(chatId: Int)
    func markAsRead(chatId: Int)
}

class SignalRService: SignalRServiceProtocol, ObservableObject {
     var lastSentChatId: Int?
    @Published var seenStatus: SeenStatus? // ✅ ADD THIS

    private var connection: HubConnection
    private var connectionDelegate: ConnectionDelegate?
    private var joinCompletionHandlers: [Int: (Bool) -> Void] = [:]
    private var tokenRefreshTimer: Timer?
    private var typingTimers: [Int: Timer] = [:]
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var receivedMessage: ReceivedPrivateMessage?
    @Published var receivedMessageHistory: [ReceivedPrivateMessage] = []
    @Published var connectionError: String?
    @Published var typingUsers: [String] = []
    @Published var deletedMessageId: Int?
    @Published var typingStatus: TypingStatus?
    @Published var userStatus: UserStatus? // ADD THIS
    
    public enum ConnectionState {
        case connected, disconnected, connecting, reconnecting
    }
    
    init() {
        self.connection = Self.createConnection()
        setupHandlers()
        setupConnectionDelegate()
        startTokenRefreshTimer()
    }
    
    private static func createConnection() -> HubConnection {
        let token = UserDefaults.standard.string(forKey: "authToken") ?? ""
        let baseUrl = "http://158.220.90.131:8444"
        let urlString = "\(baseUrl)/ChatHub?access_token=\(token)"
        
        print("🔗 Initializing SignalR with URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            fatalError("Invalid SignalR URL: \(urlString)")
        }
        
        return HubConnectionBuilder(url: url)
            .withLogging(minLogLevel: .debug)
            .withAutoReconnect()
            .build()
    }
    
    private func refreshConnectionWithNewToken() {
        print("🔄 Refreshing SignalR connection with new token...")
        connection.stop()
        self.connection = Self.createConnection()
        setupHandlers()
        setupConnectionDelegate()
        connect()
    }
    
    private func startTokenRefreshTimer() {
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkTokenAndReconnectIfNeeded()
        }
    }
    
    private func checkTokenAndReconnectIfNeeded() {
        guard let token = UserDefaults.standard.string(forKey: "authToken"), !token.isEmpty else {
            print("🔐 No token found - cannot connect SignalR")
            return
        }
        
        if connectionState == .disconnected {
            print("🔄 Token available but disconnected - reconnecting...")
            connect()
        }
    }
    
    private func setupHandlers() {
        connection.on(method: "ReceivePrivateMessage") { [weak self] (messageData: ReceivedPrivateMessage) in
            print("📥 SignalR: NEW PRIVATE message received")
            print("📥 From: \(messageData.from ?? "nil")")
            print("📥 Text: \(messageData.text ?? "nil")")
            print("📥 ChatId from server: \(messageData.chatId ?? 0)")
            
            DispatchQueue.main.async {
                // Store the message for the publisher
                self?.receivedMessage = messageData
                
//                // ALSO post notification with the raw message for other observers
//                NotificationCenter.default.post(
//                    name: Notification.Name("NewMessageReceived"),
//                    object: nil,
//                    userInfo: [
//                        "rawMessage": messageData,
//                        "source": "signalR"
//                    ]
//                )
//                
//                print("✅ SignalR: Message stored and notification sent")
            }
        }
        
        // 2. Handle MESSAGE HISTORY
        connection.on(method: "ReceiveMessageHistory") { [weak self] (messages: [ReceivedPrivateMessage]) in
            print("📚 SignalR: Received \(messages.count) historical messages")
            
            DispatchQueue.main.async {
                self?.receivedMessageHistory = messages
            }
        }
        
        // 3. Handle DELETED messages
        connection.on(method: "MessageDeleted") { [weak self] (messageId: Int) in
            print("🗑️ SignalR: Message \(messageId) was deleted")
            DispatchQueue.main.async {
                self?.deletedMessageId = messageId
            }
        }
        
        // 4. Handle TYPING indicator
        connection.on(method: "UserIsTyping") { [weak self] (chatId: Int, senderName: String) in
            print("⌨️ SignalR: User '\(senderName)' is typing in chat \(chatId)")
            
            DispatchQueue.main.async {
                self?.typingStatus = TypingStatus(
                    chatId: chatId,
                    userName: senderName,
                    timestamp: Date()
                )
                
                self?.typingTimers[chatId]?.invalidate()
                self?.typingTimers[chatId] = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        if self?.typingStatus?.chatId == chatId {
                            self?.typingStatus = nil
                        }
                        self?.typingTimers.removeValue(forKey: chatId)
                    }
                }
            }
        }
        
        // 5. ADD THIS: Handle USER STATUS changes
        connection.on(method: "UserStatusChanged") { [weak self] (userName: String, isOnline: Bool) in
            print("👤 SignalR: User '\(userName)' is now \(isOnline ? "online" : "offline")")
            
            DispatchQueue.main.async {
                self?.userStatus = UserStatus(
                    userName: userName,
                    isOnline: isOnline,
                    lastSeen: isOnline ? nil : Date()
                )
            }
        }
        
        // 6. Handle connection errors
        connection.on(method: "Error") { [weak self] (error: String) in
            print("❌ SignalR Server Error: \(error)")
            DispatchQueue.main.async {
                self?.connectionError = error
            }
        }
        
        // 7. Handle user joined/left notifications
        connection.on(method: "UserJoined") { [weak self] (chatId: Int, userName: String) in
            print("👤 SignalR: User \(userName) joined chat \(chatId)")
        }
        
        connection.on(method: "UserLeft") { [weak self] (chatId: Int, userName: String) in
            print("👤 SignalR: User \(userName) left chat \(chatId)")
        }
        // ✅ ADD THIS: Listen for MessagesSeenByPartner event
        // ✅ CORRECT: Handle MessagesSeenByPartner (matches JavaScript)
          // This is the only event your server sends for seen status
          connection.on(method: "MessagesSeenByPartner") { [weak self] (chatId: Int) in
              print("👁️✅ SignalR: Partner has seen ALL messages in chat \(chatId)")
              
              DispatchQueue.main.async {
                  // Store the seen status
                  self?.seenStatus = SeenStatus(
                      chatId: chatId,
                      messageId: 0, // 0 means all messages
                      userName: "partner",
                      timestamp: Date()
                  )
              }
          }
        
        print("✅ SignalR handlers setup completed with typing and status support")
    }
    
    func sendTypingIndicator(chatId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot send typing indicator - SignalR not connected")
            return
        }
        
        print("⌨️ SignalR: Sending typing indicator for chat \(chatId)")
        
        connection.invoke(method: "Typing", chatId) { [weak self] error in
            if let error = error {
                print("❌ SignalR Typing indicator failed: \(error)")
            }
        }
    }
    
    // ADD THIS: Mark messages as read
    func markAsRead(chatId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot mark as read - SignalR not connected")
            return
        }
        
        print("✅ SignalR: Marking chat \(chatId) as read")
        
        connection.invoke(method: "MarkAsRead", chatId) { [weak self] error in
            if let error = error {
                print("❌ SignalR MarkAsRead failed: \(error)")
            } else {
                print("✅ SignalR: Successfully marked chat \(chatId) as read")
            }
        }
    }
    
    func joinChat(chatId: Int, completion: ((Bool) -> Void)? = nil) {
        guard connectionState == .connected else {
            print("❌ Cannot join chat - SignalR not connected")
            completion?(false)
            return
        }
        
        print("🚪 SignalR: Joining room \(chatId)")
        
        if let completion = completion {
            joinCompletionHandlers[chatId] = completion
        }
        
        connection.invoke(method: "JoinRoom", chatId) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ SignalR JoinRoom failed: \(error)")
                    self?.connectionError = "JoinRoom failed: \(error.localizedDescription)"
                    completion?(false)
                    self?.joinCompletionHandlers.removeValue(forKey: chatId)
                } else {
                    print("✅ SignalR JoinRoom successful for chat \(chatId)")
                    completion?(true)
                    self?.joinCompletionHandlers.removeValue(forKey: chatId)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.getMessages(chatId: chatId)
                    }
                }
            }
        }
    }
    
    private func setupConnectionDelegate() {
        connectionDelegate = ConnectionDelegate { [weak self] in
            DispatchQueue.main.async {
                self?.connectionState = .connected
                self?.connectionError = nil
                print("✅ SignalR connected successfully")
            }
        } connectionDidFail: { [weak self] error in
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                self?.connectionError = error.localizedDescription
                print("❌ SignalR connection failed: \(error)")
            }
        } connectionDidClose: { [weak self] error in
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                if let error = error {
                    self?.connectionError = error.localizedDescription
                    print("🔌 SignalR connection closed with error: \(error)")
                } else {
                    print("🔌 SignalR connection closed")
                }
            }
        }
        
        connection.delegate = connectionDelegate
    }
    
    func connect() {
        guard let token = UserDefaults.standard.string(forKey: "authToken"), !token.isEmpty else {
            print("🔐 Cannot connect SignalR - no authentication token found")
            connectionError = "No authentication token. Please login again."
            return
        }
        
        guard connectionState != .connected && connectionState != .connecting else {
            print("⚠️ SignalR already connected or connecting")
            return
        }
        
        connectionState = .connecting
        connectionError = nil
        print("🔗 Connecting to SignalR with token...")
        
        connection.start()
    }
    
    func disconnect() {
        connection.stop()
        connectionState = .disconnected
        print("🔌 Disconnected from SignalR")
    }
 
    func getMessages(chatId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot get messages - SignalR not connected")
            return
        }
        
        print("📨 SignalR: Requesting message history for chat \(chatId)")
        
        connection.invoke(method: "GetMessages", chatId) { [weak self] error in
            if let error = error {
                print("❌ SignalR GetMessages failed: \(error)")
                DispatchQueue.main.async {
                    self?.connectionError = "GetMessages failed: \(error.localizedDescription)"
                }
            } else {
                print("✅ SignalR GetMessages request sent - waiting for ReceiveMessageHistory")
            }
        }
    }
    
    func sendMessage(_ message: String, chatId: Int, photoUrl: String? = nil) {
        guard connectionState == .connected else {
            print("❌ Cannot send message - SignalR not connected")
            return
        }
        
        // Validate inputs
        guard chatId > 0 else {
            print("❌ Cannot send message - invalid chatId: \(chatId)")
            DispatchQueue.main.async {
                self.connectionError = "Invalid chat ID"
            }
            return
        }
        
        guard !message.isEmpty else {
            print("❌ Cannot send message - empty message")
            return
        }
        
        // Store the chat ID we're sending to
        lastSentChatId = chatId
        print("📤 SignalR: Sending private message '\(message)' to chat \(chatId) with photo: \(photoUrl ?? "nil")")
        
        // UPDATED: Pass 3 parameters (message, chatId, photoUrl)
        connection.invoke(method: "SendPrivateMessage", message, chatId, photoUrl) { [weak self] error in
            if let error = error {
                print("❌ SignalR SendPrivateMessage failed: \(error)")
                DispatchQueue.main.async {
                    self?.connectionError = "Send failed: \(error.localizedDescription)"
                    
                    // POST NOTIFICATION to remove optimistic message
                    NotificationCenter.default.post(
                        name: Notification.Name("MessageSendFailed"),
                        object: nil,
                        userInfo: [
                            "chatId": chatId,
                            "message": message,
                            "error": error.localizedDescription
                        ]
                    )
                }
            } else {
                print("✅ SignalR SendPrivateMessage successful")
            }
        }
    }
    
    func deleteMessage(messageId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot delete message - SignalR not connected")
            return
        }
        
        print("🗑️ SignalR: Deleting message \(messageId)")
        
        connection.invoke(method: "DeleteMessage", messageId) { [weak self] error in
            if let error = error {
                print("❌ SignalR DeleteMessage failed: \(error)")
                DispatchQueue.main.async {
                    self?.connectionError = "Delete failed: \(error.localizedDescription)"
                }
            } else {
                print("✅ SignalR DeleteMessage successful")
            }
        }
    }
    
    func leaveChat(chatId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot leave chat - SignalR not connected")
            return
        }
        
        print("🚪 SignalR: Leaving room \(chatId)")
        
        connection.invoke(method: "LeaveRoom", chatId) { [weak self] error in
            if let error = error {
                print("❌ SignalR LeaveRoom failed: \(error)")
                DispatchQueue.main.async {
                    self?.connectionError = "LeaveRoom failed: \(error.localizedDescription)"
                }
            } else {
                print("✅ SignalR LeaveRoom successful")
            }
        }
    }
    
    func checkConnectionHealth() -> Bool {
        let isHealthy = connectionState == .connected
        print("🏥 SignalR Health Check: \(isHealthy ? "Healthy" : "Unhealthy")")
        return isHealthy
    }
    
    func clearReceivedHistory() {
        receivedMessageHistory.removeAll()
    }
    
    func getDebugInfo() -> String {
        return """
        🔗 SignalR Status:
        - State: \(connectionState)
        - Error: \(connectionError ?? "None")
        - Last Message: \(receivedMessage?.text ?? "None")
        - History Messages: \(receivedMessageHistory.count)
        - Deleted Message ID: \(deletedMessageId ?? 0)
        - Typing Status: \(typingStatus?.userName ?? "None")
        - User Status: \(userStatus?.userName ?? "None") - \(userStatus?.isOnline ?? false ? "Online" : "Offline")
        """
    }
}

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
        print("🔗 SignalR: Connection opened successfully")
        connectionDidOpen()
    }
    
    func connectionDidFailToOpen(error: Error) {
        print("❌ SignalR: Connection failed to open - \(error)")
        
        if let signalRError = error as? SignalRError {
            switch signalRError {
            case .webError(statusCode: 401):
                print("🔐 SignalR: Authentication failed (401) - token may be expired")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SignalRAuthenticationFailed"),
                        object: nil
                    )
                }
            default:
                break
            }
        }
        
        connectionDidFail(error)
    }
    
    func connectionDidClose(error: Error?) {
        if let error = error {
            print("🔌 SignalR: Connection closed with error - \(error)")
            
            if let signalRError = error as? SignalRError,
               case .webError(statusCode: 401) = signalRError {
                print("🔐 SignalR: Connection closed due to authentication error")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SignalRAuthenticationFailed"),
                        object: nil
                    )
                }
            }
        } else {
            print("🔌 SignalR: Connection closed normally")
        }
        connectionDidClose(error)
    }
    
    func connectionWillReconnect(error: Error) {
        print("🔄 SignalR: Will attempt to reconnect - \(error)")
    }
    
    func connectionDidReconnect() {
        print("✅ SignalR: Successfully reconnected")
    }
}
