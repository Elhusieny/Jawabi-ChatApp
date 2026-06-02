import Foundation
import Combine
import SignalRClient

protocol SignalRServiceProtocol: ObservableObject {
    var connectionState: SignalRService.ConnectionState { get }
    var receivedMessage: ReceivedPrivateMessage? { get }
    var connectionError: String? { get }
    var typingStatus: TypingStatus? { get }
    var userStatus: UserStatus? { get }
    var seenStatus: SeenStatus? { get }
    
    func connect()
    func disconnect()
    func sendMessage(
        _ message: String,
        chatId: Int,
        fileUrl: String?,
        fileName: String?,
        fileSize: Int64?,
        fileExtension: String?,
        type: MessageType?
    )
    func joinChat(chatId: Int, completion: ((Bool) -> Void)?)
    func leaveChat(chatId: Int)
    func getMessages(chatId: Int)
    func deleteMessage(messageId: Int)
    func sendTypingIndicator(chatId: Int)
    func markAsRead(chatId: Int)
    func sendGroupMessage(
        _ message: String,
        chatId: Int,
        fileUrl: String?,
        fileName: String?,
        fileSize: Int64?,
        fileExtension: String?,
        type: MessageType?
    )
}

class SignalRService: SignalRServiceProtocol, ObservableObject {
  
    
   
    
    @Published var lastSentChatId: Int?
    @Published var seenStatus: SeenStatus?
    
    @Published var fileStatusUpdated: FileStatusUpdatedData?
    @Published var errorMessage: String?
    @Published var privateMessageHistory: [MessageWithSeenStatus] = []
    @Published var isFileScanning = false
    
    @Published var blockedMessages: [BlockedMessageInfo] = []
    
    var connection: HubConnection
    private var connectionDelegate: ConnectionDelegate?
    private var joinCompletionHandlers: [Int: (Bool) -> Void] = [:]
    private var tokenRefreshTimer: Timer?
    private var typingTimers: [Int: Timer] = [:]
    private var pendingMessageCallbacks: [Int: (Result<ScannedFileResult?, Error>) -> Void] = [:]
    private var nextCallbackId = 0
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var receivedMessage: ReceivedPrivateMessage?
    @Published var receivedMessageHistory: [ReceivedPrivateMessage] = []
    @Published var connectionError: String?
    @Published var typingUsers: [String] = []
    @Published var deletedMessageId: Int?
    @Published var typingStatus: TypingStatus?
    @Published var userStatus: UserStatus?
    
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
    func leaveChat(chatId: Int) {
        // Call the completion version and ignore the result
        leaveChat(chatId: chatId) { _, _ in }
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
                self?.receivedMessage = messageData
            }
        }
        // Add this after the ReceivePrivateMessage handler (around line 136)
        connection.on(method: "ReceiveGroupMessage") { [weak self] (messageData: ReceivedPrivateMessage) in
            print("📥 SignalR: GROUP message received")
            print("📥 From: \(messageData.from ?? "nil")")
            print("📥 Text: \(messageData.text ?? "nil")")
            print("📥 ChatId: \(messageData.chatId ?? 0)")
            
            DispatchQueue.main.async {
                self?.receivedMessage = messageData
            }
        }
        
        connection.on(method: "ReceiveMessageHistory") { [weak self] (messages: [ReceivedPrivateMessage]) in
            print("📚 SignalR: Received \(messages.count) historical messages")
            DispatchQueue.main.async {
                self?.receivedMessageHistory = messages
            }
        }
        
        connection.on(method: "MessageDeleted") { [weak self] (messageId: Int) in
            print("🗑️ SignalR: Message \(messageId) was deleted")
            DispatchQueue.main.async {
                self?.deletedMessageId = messageId
            }
        }
        
        connection.on(method: "UserIsTyping") { [weak self] (chatId: Int, senderName: String) in
            print("⌨️ SignalR: User '\(senderName)' is typing in chat \(chatId)")
            DispatchQueue.main.async {
                self?.typingStatus = TypingStatus(chatId: chatId, userName: senderName, timestamp: Date())
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
        
        connection.on(method: "UserStatusChanged") { [weak self] (userName: String, isOnline: Bool) in
            print("👤 SignalR: User '\(userName)' is now \(isOnline ? "online" : "offline")")
            DispatchQueue.main.async {
                self?.userStatus = UserStatus(userName: userName, isOnline: isOnline, lastSeen: isOnline ? nil : Date())
            }
        }
        
        connection.on(method: "Error") { [weak self] (error: String) in
            print("❌ SignalR Server Error: \(error)")
            DispatchQueue.main.async {
                self?.connectionError = error
            }
        }
        
        connection.on(method: "UserJoined") { [weak self] (chatId: Int, userName: String) in
            print("👤 SignalR: User \(userName) joined chat \(chatId)")
        }
        
        connection.on(method: "UserLeft") { [weak self] (chatId: Int, userName: String) in
            print("👤 SignalR: User \(userName) left chat \(chatId)")
        }
        
        connection.on(method: "MessagesSeenByPartner") { [weak self] (chatId: Int) in
            print("👁️✅ SignalR: Partner has seen ALL messages in chat \(chatId)")
            DispatchQueue.main.async {
                self?.seenStatus = SeenStatus(chatId: chatId, messageId: 0, userName: "partner", timestamp: Date())
            }
        }
        
        connection.on(method: "FileStatusUpdated") { [weak self] (fileData: FileStatusUpdatedData) in
            print("🔍 SignalR: File status updated received")
            print("   - messageId: \(fileData.messageId)")
            print("   - fileUrl: \(fileData.fileUrl)")
            print("   - isSafe: \(fileData.isSafe)")
            print("   - fileName: \(fileData.fileName ?? "nil")")
            
            DispatchQueue.main.async {
                self?.isFileScanning = false
                self?.fileStatusUpdated = fileData
                
                if !fileData.isSafe {
                    print("⚠️ File blocked: \(fileData.fileUrl)")
                }
            }
        }
        
        connection.on(method: "ReceiveErrorMessage") { [weak self] (errorMsg: String) in
            print("❌ SignalR: Error message received: \(errorMsg)")
            DispatchQueue.main.async {
                self?.errorMessage = errorMsg
                self?.isFileScanning = false
                
                if errorMsg.contains("blocked") || errorMsg.contains("flagged") || errorMsg.contains("malicious") {
                    print("🚫 Message/URL was blocked: \(errorMsg)")
                }
                
                self?.showErrorMessageAlert(errorMsg)
            }
        }
        
        connection.on(method: "ReceivePrivateMessageHistory") { [weak self] (messages: [MessageWithSeenStatus]) in
            print("📚 SignalR: Received \(messages.count) historical messages with seen status")
            DispatchQueue.main.async {
                self?.privateMessageHistory = messages
                
                let receivedMessages = messages.map { msg -> ReceivedPrivateMessage in
                    return ReceivedPrivateMessage(
                        From: msg.from,
                        from: msg.from,
                        Text: msg.displayText,
                        text: msg.displayText,
                        TimeStamp: msg.timeStamp,
                        timeStamp: msg.timeStamp,
                        ChatId: nil,
                        chatId: nil,
                        MessageId: msg.id,
                        messageId: msg.id,
                        isFile: msg.isFile,
                        isSafe: msg.isSafe,
                        fileUrl: msg.fileUrl,
                        fileName: msg.fileName,
                        fileSize: msg.fileSize,
                        extension: msg.extension,
                        type: msg.type
                    )
                }
                self?.receivedMessageHistory = receivedMessages
            }
        }
        
        print("✅ SignalR handlers setup completed")
    }
    
    // MARK: - Send Message
    
    func sendMessage(
        _ message: String,
        chatId: Int,
        fileUrl: String? = nil,
        fileName: String? = nil,
        fileSize: Int64? = nil,
        fileExtension: String? = nil,
        type: MessageType? = nil
    ) {
        guard connectionState == .connected else {
            print("❌ Cannot send message - SignalR not connected")
            DispatchQueue.main.async { self.connectionError = "SignalR not connected" }
            return
        }
        
        guard chatId > 0 else {
            print("❌ Cannot send message - invalid chatId: \(chatId)")
            DispatchQueue.main.async { self.connectionError = "Invalid chat ID" }
            return
        }
        
        lastSentChatId = chatId
        
        let finalType: MessageType
        if let providedType = type {
            finalType = providedType
        } else {
            finalType = resolveMessageType(message: message, fileUrl: fileUrl, fileExtension: fileExtension)
        }
        
        // ─── FIX: Voice messages skip scanning entirely ───────────────────────
        // Voice recordings (type == .voice / rawValue == 2) are audio files
        // that come from the device microphone and do not need antivirus scanning.
        // Setting isFileScanning = false here ensures the scanning indicator is
        // never shown and FileStatusUpdated is not awaited for voice messages.
        let isVoiceMessage = finalType == .voice
        if isVoiceMessage {
            print("🎙️ Voice message detected — skipping file scan")
        }
        // ─────────────────────────────────────────────────────────────────────
        
        // For text messages send fileSize as 0; honour the passed value for all others
        let finalFileSize: Int64
        if finalType == .text {
            finalFileSize = 0
        } else {
            finalFileSize = fileSize ?? 0
        }
        
        let finalFileName  = fileName      ?? ""
        let finalExtension = fileExtension ?? ""
        let finalFileUrl   = fileUrl       ?? ""
        
        print("📤 SignalR: Sending message to chat \(chatId)")
        print("   - Type: \(finalType) (raw: \(finalType.rawValue))")
        print("   - Message: \(message.prefix(50))")
        print("   - FileName: \(finalFileName)")
        print("   - FileSize: \(finalFileSize)")
        print("   - Extension: \(finalExtension)")
        print("   - Scanning: \(isVoiceMessage ? "SKIPPED (voice)" : "enabled")")
        
        // Only set scanning flag for non-text, non-voice files
        if finalType != .text && !isVoiceMessage {
            self.isFileScanning = true
        }
        
        connection.invoke(
            method: "SendPrivateMessage",
            message,
            chatId,
            finalFileUrl,
            finalFileName,
            finalFileSize,
            finalExtension,
            finalType.rawValue
        ) { [weak self] error in
            DispatchQueue.main.async {
                // Always clear scanning flag on completion
                self?.isFileScanning = false
                
                if let error = error {
                    print("❌ SignalR SendPrivateMessage failed: \(error)")
                    self?.connectionError = "Send failed: \(error.localizedDescription)"
                } else {
                    print("✅ SignalR SendPrivateMessage successful")
                }
            }
        }
    }
    // MARK: - Send Group Message

    func sendGroupMessage(
        _ message: String,
        chatId: Int,
        fileUrl: String? = nil,
        fileName: String? = nil,
        fileSize: Int64? = nil,
        fileExtension: String? = nil,
        type: MessageType? = nil
    ) {
        guard connectionState == .connected else {
            print("❌ Cannot send group message - SignalR not connected")
            DispatchQueue.main.async { self.connectionError = "SignalR not connected" }
            return
        }
        
        guard chatId > 0 else {
            print("❌ Cannot send group message - invalid chatId: \(chatId)")
            DispatchQueue.main.async { self.connectionError = "Invalid chat ID" }
            return
        }
        
        lastSentChatId = chatId
        
        let finalType: MessageType
        if let providedType = type {
            finalType = providedType
        } else {
            finalType = resolveMessageType(message: message, fileUrl: fileUrl, fileExtension: fileExtension)
        }
        
        let isVoiceMessage = finalType == .voice
        if isVoiceMessage {
            print("🎙️ Voice message detected — skipping file scan")
        }
        
        let finalFileSize: Int64
        if finalType == .text {
            finalFileSize = 0
        } else {
            finalFileSize = fileSize ?? 0
        }
        
        let finalFileName  = fileName      ?? ""
        let finalExtension = fileExtension ?? ""
        let finalFileUrl   = fileUrl       ?? ""
        
        print("📤 SignalR: Sending GROUP message to chat \(chatId)")
        print("   - Type: \(finalType) (raw: \(finalType.rawValue))")
        print("   - Message: \(message.prefix(50))")
        print("   - FileName: \(finalFileName)")
        print("   - FileSize: \(finalFileSize)")
        print("   - Extension: \(finalExtension)")
        print("   - Scanning: \(isVoiceMessage ? "SKIPPED (voice)" : "enabled")")
        
        if finalType != .text && !isVoiceMessage {
            self.isFileScanning = true
        }
        
        connection.invoke(
            method: "SendGroupMessage",
            message,
            chatId,
            finalFileUrl,
            finalFileName,
            finalFileSize,
            finalExtension,
            finalType.rawValue
        ) { [weak self] error in
            DispatchQueue.main.async {
                self?.isFileScanning = false
                if let error = error {
                    print("❌ SignalR SendGroupMessage failed: \(error)")
                    self?.connectionError = "Send failed: \(error.localizedDescription)"
                } else {
                    print("✅ SignalR SendGroupMessage successful")
                }
            }
        }
    }
    // MARK: - Message Type Resolution
    
    /// Resolves the correct MessageType from available metadata.
    /// Voice (rawValue 2) is matched before falling back to .file so that
    /// audio recordings are never mistakenly treated as generic files.
    private func resolveMessageType(message: String, fileUrl: String?, fileExtension: String?) -> MessageType {
        
        let audioExtensions = ["m4a", "mp3", "wav", "aac", "ogg", "flac", "m4r", "caf", "aiff"]
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"]
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]
        
        // 1. Check explicit fileExtension parameter first
        if let ext = fileExtension, !ext.isEmpty {
            let lower = ext.lowercased()
            if imageExtensions.contains(lower) { return .image }
            if videoExtensions.contains(lower) { return .video }
            // FIX: audio extensions → .voice (rawValue 2), NOT .file
            if audioExtensions.contains(lower) { return .voice }
            return .file
        }
        
        // 2. Derive from fileUrl extension
        if let url = fileUrl, !url.isEmpty {
            let ext = (url as NSString).pathExtension.lowercased()
            if imageExtensions.contains(ext) { return .image }
            if videoExtensions.contains(ext) { return .video }
            // FIX: audio extensions → .voice (rawValue 2), NOT .file
            if audioExtensions.contains(ext) { return .voice }
            if !ext.isEmpty { return .file }
        }
        
        // 3. Heuristic: check message text for audio indicators
        let lower = message.lowercased()
        let audioKeywords = audioExtensions.map { ".\($0)" }
        if audioKeywords.contains(where: { lower.contains($0) }) {
            return .voice
        }
        
        return .text
    }
    
    // MARK: - Send with Scan (non-voice files only)
    
    func sendMessageWithScan(_ message: String, chatId: Int, photoUrl: String? = nil, isFile: Bool = false) -> AnyPublisher<ScannedFileResult?, Error> {
        guard connectionState == .connected else {
            return Fail(error: NSError(domain: "SignalR", code: -1, userInfo: [NSLocalizedDescriptionKey: "SignalR not connected"]))
                .eraseToAnyPublisher()
        }
        guard chatId > 0 else {
            return Fail(error: NSError(domain: "SignalR", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid chat ID"]))
                .eraseToAnyPublisher()
        }
        guard !message.isEmpty else {
            return Fail(error: NSError(domain: "SignalR", code: -3, userInfo: [NSLocalizedDescriptionKey: "Empty message"]))
                .eraseToAnyPublisher()
        }
        
        let callbackId = nextCallbackId
        nextCallbackId += 1
        
        return Future<ScannedFileResult?, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "SignalR", code: -4, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            self.pendingMessageCallbacks[callbackId] = { result in
                switch result {
                case .success(let scanResult):
                    if scanResult?.isSafe ?? true {
                        self.sendMessage(message, chatId: chatId)
                    }
                    promise(.success(scanResult))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
            
            self.isFileScanning = true
            
            print("🔍 SignalR: Sending message with file scan to chat \(chatId)")
            self.connection.invoke(method: "SendPrivateMessageWithScan", message, chatId, photoUrl ?? "", isFile) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.isFileScanning = false
                        self.pendingMessageCallbacks.removeValue(forKey: callbackId)
                        promise(.failure(error))
                    }
                }
            }
        }
        .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: {
            NSError(domain: "SignalR", code: -5, userInfo: [NSLocalizedDescriptionKey: "File scan timeout"])
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - Chat Actions
    
    func sendTypingIndicator(chatId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot send typing indicator - SignalR not connected"); return
        }
        connection.invoke(method: "Typing", chatId) { error in
            if let error = error { print("❌ SignalR Typing indicator failed: \(error)") }
        }
    }
    
    func markAsRead(chatId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot mark as read - SignalR not connected"); return
        }
        connection.invoke(method: "MarkAsRead", chatId) { error in
            if let error = error { print("❌ SignalR MarkAsRead failed: \(error)") }
            else { print("✅ SignalR: Successfully marked chat \(chatId) as read") }
        }
    }
    
    func joinChat(chatId: Int, completion: ((Bool) -> Void)? = nil) {
        guard connectionState == .connected else {
            print("❌ Cannot join chat - SignalR not connected")
            completion?(false); return
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
    
    // In SignalRService.swift - Update leaveChat method to support completion
    func leaveChat(chatId: Int, completion: ((Bool, Error?) -> Void)? = nil) {
        guard connectionState == .connected else {
            print("❌ Cannot leave chat - SignalR not connected")
            completion?(false, NSError(domain: "SignalR", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "SignalR not connected"]))
            return
        }
        
        print("🚪 SignalR: Leaving room \(chatId)")
        
        connection.invoke(method: "LeaveRoom", chatId) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ SignalR LeaveRoom failed: \(error)")
                    self.connectionError = "LeaveRoom failed: \(error.localizedDescription)"
                    completion?(false, error)
                } else {
                    print("✅ SignalR LeaveRoom successful for chat \(chatId)")
                    completion?(true, nil)
                }
            }
        }
    }
    func getMessages(chatId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot get messages - SignalR not connected"); return
        }
        connection.invoke(method: "GetMessages", chatId) { [weak self] error in
            if let error = error {
                print("❌ SignalR GetMessages failed: \(error)")
                DispatchQueue.main.async {
                    self?.connectionError = "GetMessages failed: \(error.localizedDescription)"
                }
            } else {
                print("✅ SignalR GetMessages request sent")
            }
        }
    }
    
    func getMessagesWithSeenStatus(chatId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot get messages - SignalR not connected"); return
        }
        connection.invoke(method: "GetMessageHistory", chatId) { [weak self] error in
            if let error = error {
                print("❌ SignalR GetMessageHistory failed: \(error)")
                DispatchQueue.main.async {
                    self?.connectionError = "GetMessageHistory failed: \(error.localizedDescription)"
                }
            } else {
                print("✅ SignalR GetMessageHistory request sent")
            }
        }
    }
    
    func deleteMessage(messageId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot delete message - SignalR not connected"); return
        }
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
    
    // MARK: - Connection Management
    
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
            print("⚠️ SignalR already connected or connecting"); return
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
    
    // MARK: - Helpers
    
    func sendImageMessage(_ imageData: Data, fileName: String, chatId: Int) {
        guard connectionState == .connected else {
            print("❌ Cannot send image - SignalR not connected"); return
        }
        guard chatId > 0 else {
            print("❌ Cannot send image - invalid chatId: \(chatId)"); return
        }
        self.isFileScanning = true
        print("🖼️ SignalR: Sending image '\(fileName)' to chat \(chatId)")
    }
    
    func addBlockedMessage(_ info: BlockedMessageInfo) {
        DispatchQueue.main.async { [weak self] in
            self?.blockedMessages.append(info)
            if self?.blockedMessages.count ?? 0 > 50 {
                self?.blockedMessages.removeFirst()
            }
        }
    }
    
    func clearFileStatus()    { fileStatusUpdated = nil }
    func clearErrorMessage()  { errorMessage = nil }
    func clearMessageHistory(){ privateMessageHistory.removeAll() }
    
    private func showErrorMessageAlert(_ message: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("SignalRErrorMessage"),
            object: nil,
            userInfo: ["message": message]
        )
    }
    
    func checkConnectionHealth() -> Bool {
        let isHealthy = connectionState == .connected
        print("🏥 SignalR Health Check: \(isHealthy ? "Healthy" : "Unhealthy")")
        return isHealthy
    }
    
    func clearReceivedHistory() { receivedMessageHistory.removeAll() }
    
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

// MARK: - Connection Delegate

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
                    NotificationCenter.default.post(name: NSNotification.Name("SignalRAuthenticationFailed"), object: nil)
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
                    NotificationCenter.default.post(name: NSNotification.Name("SignalRAuthenticationFailed"), object: nil)
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
