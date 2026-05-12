import Foundation
import Alamofire
import UIKit
import Combine


class ChatViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var users: [GetAllUsersDM] = []
    @Published var currentChat: Chat?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var typingUsers: [String] = []
    @Published var typingIndicators: [Int: String] = [:]
    @Published var userStatuses: [String: Bool] = [:] // userName -> isOnline
    
    private var cancellables = Set<AnyCancellable>()
    private var joinedChats: Set<Int> = []
    private var pendingMessages: [String: (message: String, chatId: Int)] = [:]
    private var currentChatId: Int?
    private var refreshTimer: Timer?
    private var typingDebounceTimer: Timer?
    
    private let networkService = GetAllChatsService.shared
    private let getAllUsersService = GetAllUsersService.shared
     let signalRService: any SignalRServiceProtocol
    private var lastSentChatId: Int?

     var optimisticMessageTracking: [Int: String] = [:] // [tempMessageId: text]

    // Message deduplication
    private var processedMessageIds = Set<String>()
    private var lastProcessedMessageTime: Date?
    private let messageDeduplicationWindow: TimeInterval = 2.0
    @Published var chatsUpdated = Date()
    
    @Published var messageSeenStatus: [Int: [String]] = [:] // ✅ ADD THIS: messageId -> [userNames]

    @Published var messageDeliveryStatus: [Int: Bool] = [:] // ✅ ADD: messageId -> isDelivered
    // ✅ ADD THIS: File status updates tracking
       @Published var fileStatusUpdates: [Int: FileStatusUpdatedData] = [:] // messageId -> file data
    
    
        private var lastUsersFetchTime: Date?
        private let usersCacheDuration: TimeInterval = 300 // 5 minutes cache
        
      
    // MARK: - Initialization
       
       init(signalRService: any SignalRServiceProtocol = SignalRService()) {
           self.signalRService = signalRService
           setupSignalRHandlers()
           loadSavedChats()
           fetchAllChatsFromServer()
           connectSignalR()
           setupAppLifecycleHandlers()
       }
       
       deinit {
           stopPolling()
           disconnectSignalR()
           typingDebounceTimer?.invalidate()
       }
    // MARK: - Persistent User Caching
       
       private func saveUsersToCache() {
           guard !users.isEmpty else { return }
           
           do {
               let encoder = JSONEncoder()
               let usersData = try encoder.encode(users)
               UserDefaults.standard.set(usersData, forKey: "cached_users_\(getCurrentUsername())")
               UserDefaults.standard.set(Date(), forKey: "cached_users_time_\(getCurrentUsername())")
               print("💾 Saved \(users.count) users to persistent cache")
           } catch {
               print("❌ Failed to cache users: \(error)")
           }
       }
       
       private func loadUsersFromCache() -> Bool {
           let username = getCurrentUsername()
           
           guard let usersData = UserDefaults.standard.data(forKey: "cached_users_\(username)"),
                 let cachedTime = UserDefaults.standard.object(forKey: "cached_users_time_\(username)") as? Date else {
               print("📦 No cached users found")
               return false
           }
           
           // Check if cache is still valid (optional - you might always load cache)
           let isCacheValid = Date().timeIntervalSince(cachedTime) < usersCacheDuration
           
           do {
               let decoder = JSONDecoder()
               let cachedUsers = try decoder.decode([GetAllUsersDM].self, from: usersData)
               self.users = cachedUsers
               self.lastUsersFetchTime = cachedTime
               print("📦 Loaded \(cachedUsers.count) users from persistent cache (valid: \(isCacheValid))")
               return true
           } catch {
               print("❌ Failed to load cached users: \(error)")
               return false
           }
       }
       
       func loadAllUsers(forceRefresh: Bool = false) {
           // Try to load from cache first (synchronous, instant)
           if !forceRefresh && users.isEmpty {
               let hadCachedUsers = loadUsersFromCache()
               if hadCachedUsers {
                   // We have cached data, but still refresh in background
                   // to keep it updated without blocking UI
                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                       self?.refreshUsersInBackground()
                   }
                   return
               }
           }
           
           // Check if we have fresh in-memory cache
           if !forceRefresh,
              !users.isEmpty,
              let lastFetch = lastUsersFetchTime,
              Date().timeIntervalSince(lastFetch) < usersCacheDuration {
               print("📦 Using fresh in-memory users (\(users.count) users)")
               return
           }
           
           // Need to fetch from server
           fetchUsersFromServer()
       }
       
       private func refreshUsersInBackground() {
           // Only refresh if cache is older than 5 minutes
           if let lastFetch = lastUsersFetchTime,
              Date().timeIntervalSince(lastFetch) < usersCacheDuration {
               print("📦 Cache still fresh, skipping background refresh")
               return
           }
           
           print("🔄 Refreshing users in background...")
           fetchUsersFromServer()
       }
       
       private func fetchUsersFromServer() {
           isLoading = true
           errorMessage = nil
           
           print("🌐 Fetching users from server...")
           
           getAllUsersService.getAllUsers()
               .receive(on: DispatchQueue.main)
               .sink { [weak self] completion in
                   self?.isLoading = false
                   if case .failure(let error) = completion {
                       self?.errorMessage = "Failed to load users: \(error.localizedDescription)"
                       print("❌ Failed to load users: \(error.localizedDescription)")
                   }
               } receiveValue: { [weak self] users in
                   self?.users = users
                   self?.lastUsersFetchTime = Date()
                   self?.saveUsersToCache() // Save to persistent storage
                   print("✅ Loaded \(users.count) users from server")
               }
               .store(in: &cancellables)
       }
   
    func fetchAllChatsFromServer() {
        isLoading = true
        errorMessage = nil
        
        print("🌐 Fetching all chats from server...")
        
        networkService.getAllChats()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    print("❌ Failed to fetch chats: \(error.localizedDescription)")
                    self?.errorMessage = "Failed to load chats: \(error.localizedDescription)"
                    print("💾 Using cached chats (\(self?.chats.count ?? 0) chats)")
                }
            } receiveValue: { [weak self] fetchedChats in
                print("✅ Fetched \(fetchedChats.count) chats from server")
                
                let mergedChats = fetchedChats.map { fetchedChat -> Chat in
                    return Chat(
                        id: fetchedChat.id,
                        name: fetchedChat.name,
                        pictureUrl: fetchedChat.pictureUrl,
                        type: fetchedChat.type,
                        messages: fetchedChat.messages,
                        users: fetchedChat.users,
                        unreadCount: fetchedChat.unreadCount,
                        isOnline: fetchedChat.isOnline
                    )
                }
                
                self?.chats = mergedChats.sorted { $0.lastMessageDate > $1.lastMessageDate }
                
                // Update user statuses
                for chat in mergedChats where chat.type == 1 {
                    self?.userStatuses[chat.name] = chat.isOnline
                    print("👤 User \(chat.name) is \(chat.isOnline ? "online" : "offline")")
                }
                
                self?.saveChats()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.autoJoinAllChats()
                }
            }
            .store(in: &cancellables)
    }
    
    func refreshChats() {
        fetchAllChatsFromServer()
    }
    
    // MARK: - SignalR Connection
    
    var isSignalRConnected: Bool {
        if let signalR = signalRService as? SignalRService {
            return signalR.connectionState == .connected
        }
        return false
    }
    
    private func setupSignalRHandlers() {
        guard let signalR = signalRService as? SignalRService else { return }
        
        signalR.$connectionState
            .sink { [weak self] state in
                switch state {
                case .connected:
                    print("✅ SignalR connected - joining all chat rooms")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.autoJoinAllChats()
                    }
                case .disconnected:
                    print("❌ SignalR disconnected - will retry")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self?.connectSignalR()
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // FIXED: Single message handler with proper deduplication
        signalR.$receivedMessage
            .compactMap { $0 }
            .sink { [weak self] receivedMessage in
                print("📨 RAW SignalR message received")
                self?.processIncomingRealTimeMessage(receivedMessage)
            }
            .store(in: &cancellables)
        
        signalR.$receivedMessageHistory
            .sink { [weak self] messages in
                print("📚 Received message history via SignalR: \(messages.count) messages")
                self?.handleMessageHistory(messages)
            }
            .store(in: &cancellables)
        
        signalR.$typingStatus
            .compactMap { $0 }
            .sink { [weak self] typingStatus in
                self?.handleTypingIndicator(typingStatus)
            }
            .store(in: &cancellables)
        
        signalR.$userStatus
            .compactMap { $0 }
            .sink { [weak self] userStatus in
                self?.handleUserStatusChange(userStatus)
            }
            .store(in: &cancellables)
        // ✅ ADD THIS: Handle individual message seen
                signalR.$seenStatus
                    .compactMap { $0 }
                    .sink { [weak self] seenStatus in
                        // Check if this is a batch event (all messages in chat)
                        if seenStatus.messageId == 0 {
                            self?.handleAllMessagesSeen(chatId: seenStatus.chatId, userName: seenStatus.userName)
                        }
                    }
                    .store(in: &cancellables)
        // NEW: Handle FILE STATUS UPDATED
               signalR.$fileStatusUpdated
                   .compactMap { $0 }
                   .sink { [weak self] fileData in
                       print("🔍 File status updated for message \(fileData.messageId): \(fileData.isSafe ? "Safe" : "Blocked")")
                       self?.handleFileStatusUpdate(fileData)
                   }
                   .store(in: &cancellables)
               
               
        // Handle ERROR MESSAGES (blocked URLs/messages)
        signalR.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] errorMessage in
                print("❌ SignalR Error: \(errorMessage)")
                
                // Check if this is a blocked message/URL
                if errorMessage.contains("blocked") || errorMessage.contains("flagged") || errorMessage.contains("malicious") {
                    self?.handleBlockedMessage(errorMessage)
                } else {
                    // Other errors
                    DispatchQueue.main.async {
                        self?.errorMessage = errorMessage
                    }
                }
            }
            .store(in: &cancellables)
               // NEW: Handle message history with seen status
               signalR.$privateMessageHistory
                   .sink { [weak self] messages in
                       guard !messages.isEmpty else { return }
                       self?.handleMessageHistoryWithSeenStatus(messages)
                   }
                   .store(in: &cancellables)
               
               // Monitor file scanning state
               signalR.$isFileScanning
                   .sink { isScanning in
                       if isScanning {
                           print("🔍 File scanning in progress...")
                       }
                   }
                   .store(in: &cancellables)
           
            
    }

    private func fetchChatAndAddToList(chatId: Int, lastMessage: String, sender: String) {
        guard chatId > 0 else {
            print("⚠️ Skipping fetch - invalid chatId: \(chatId)")
            return
        }
        
        networkService.getChat(chatId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to fetch chat \(chatId): \(error)")
                    if chatId > 0 {
                        self?.createTemporaryChatForMessage(chatId: chatId, message: Message(
                            id: Int.random(in: 1000...9999),
                                        displayText: lastMessage,
                            name: sender,
                            timestamp: ISO8601DateFormatter().string(from: Date()),
                            isRead: false
                        ), senderName: sender)
                    }
                }
            } receiveValue: { [weak self] chat in
                guard let self = self else { return }
                
                let updatedChat = Chat(
                    id: chat.id,
                    name: chat.name,
                    pictureUrl: chat.pictureUrl,
                    type: chat.type,
                    messages: chat.messages,
                    users: chat.users,
                    unreadCount: 1,
                    isOnline: chat.isOnline
                )
                
                self.chats.insert(updatedChat, at: 0)
                self.saveChats()
                self.joinChatRoom(chatId: chatId)
                
                print("✅ Added new chat to list: \(chat.name)")
            }
            .store(in: &cancellables)
    }

   
    
    private func handleTypingIndicator(_ typingStatus: TypingStatus) {
        let currentUsername = getCurrentUsername()
        
        guard typingStatus.userName.lowercased() != currentUsername.lowercased() else {
            print("⌨️ Ignoring typing indicator from self")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.typingIndicators[typingStatus.chatId] = typingStatus.userName
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if self?.typingIndicators[typingStatus.chatId] == typingStatus.userName {
                    self?.typingIndicators.removeValue(forKey: typingStatus.chatId)
                }
            }
        }
    }
    
    func sendTypingIndicator(for chatId: Int) {
        typingDebounceTimer?.invalidate()
        
        typingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            if let signalR = self.signalRService as? SignalRService {
                signalR.sendTypingIndicator(chatId: chatId)
            }
        }
    }
    
    func getTypingStatus(for chatId: Int) -> String? {
        return typingIndicators[chatId]
    }
    
    func isUserOnline(for chat: Chat) -> Bool {
        if chat.type == 1 {
            return userStatuses[chat.name] ?? chat.isOnline
        }
        return false
    }
    
    func connectSignalR() {
        guard UserDefaults.standard.string(forKey: "authToken") != nil else {
            print("❌ Cannot connect SignalR - no auth token")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.signalRService.connect()
        }
    }
    
    private func disconnectSignalR() {
        signalRService.disconnect()
    }
    
    // MARK: - Chat Management
    
    func joinChatRoom(chatId: Int, completion: ((Bool) -> Void)? = nil) {
        guard isSignalRConnected else {
            print("❌ Cannot join chat \(chatId) - SignalR not connected")
            completion?(false)
            return
        }
        
        if joinedChats.contains(chatId) {
            print("ℹ️ Already joined chat \(chatId)")
            if currentChatId == chatId {
                markChatAsRead(chatId: chatId)
            }
            completion?(true)
            return
        }
        
        print("🚪 Joining chat room \(chatId)...")
        
        signalRService.joinChat(chatId: chatId) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.joinedChats.insert(chatId)
                    print("✅ Successfully joined chat \(chatId)")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        (self?.signalRService as? SignalRService)?.getMessages(chatId: chatId)
                    }
                    
                    self?.processPendingMessages(for: chatId)
                } else {
                    print("❌ Failed to join chat \(chatId)")
                }
                completion?(success)
            }
        }
    }
    
    func markChatAsRead(chatId: Int) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else { return }
        
        var updatedChat = chats[index]
        
        guard updatedChat.unreadCount > 0 else { return }
        
        print("✅ Marking chat \(chatId) as read (was \(updatedChat.unreadCount) unread)")
        
        updatedChat = Chat(
            id: updatedChat.id,
            name: updatedChat.name,
            pictureUrl: updatedChat.pictureUrl,
            type: updatedChat.type,
            messages: updatedChat.messages,
            users: updatedChat.users,
            unreadCount: 0,
            isOnline: updatedChat.isOnline
        )
        
        chats[index] = updatedChat
        
        if currentChat?.id == chatId {
            currentChat = updatedChat
        }
        
        saveChats()
        
        if let signalR = signalRService as? SignalRService {
            signalR.markAsRead(chatId: chatId)
        }
    }
    
     func autoJoinAllChats() {
        guard isSignalRConnected else {
            print("❌ Cannot auto-join chats - SignalR not connected")
            return
        }
         // In ChatViewModel.swift
         func refreshChats() {
             print("🔄 Manually refreshing chats from server...")
             fetchAllChatsFromServer()
         }
        print("🔄 Auto-joining \(chats.count) chats...")
        
        for chat in chats {
            if !joinedChats.contains(chat.id) {
                joinChatRoom(chatId: chat.id) { success in
                    if success {
                        print("✅ Auto-joined chat: \(chat.name)")
                    } else {
                        print("❌ Failed to auto-join chat: \(chat.name)")
                    }
                }
            }
        }
    }
    
    func leaveChatRoom(chatId: Int) {
        signalRService.leaveChat(chatId: chatId)
        joinedChats.remove(chatId)
        if currentChatId == chatId {
            currentChatId = nil
        }
        typingIndicators.removeValue(forKey: chatId)
        print("🚪 Left SignalR room for chat \(chatId)")
    }
    
    // MARK: - Message Sending
    // MARK: - URL Detection Helpers

    private func isURLString(_ text: String) -> Bool {
        // Check if the entire text is a URL
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        // Check if the entire text is a URL
        if matches.count == 1 {
            let match = matches[0]
            return match.range.location == 0 && match.range.length == text.utf16.count
        }
        return false
    }

    private func containsURL(_ text: String) -> Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return !matches.isEmpty
    }

    private func extractURLs(from text: String) -> [URL] {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        return matches.compactMap { match in
            guard let url = match.url else { return nil }
            return url
        }
    }

    private func containsURLInText(_ text: String) -> Bool {
        // Simple check for common URL patterns
        let urlPattern = "https?://[^\\s]+"
        if let _ = text.range(of: urlPattern, options: .regularExpression) {
            return true
        }
        
        // Also check for www. patterns
        let wwwPattern = "www\\.[^\\s]+\\.[^\\s]+"
        if let _ = text.range(of: wwwPattern, options: .regularExpression) {
            return true
        }
        
        return false
    }
    func sendMessage(_ text: String, chatId: Int) {
        let trimmedMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        guard isSignalRConnected else {
            errorMessage = "Not connected to chat server. Please check your connection."
            return
        }
        
        // Check if message contains URLs
        if containsURL(trimmedMessage) {
            print("🔗 Message contains URL(s) - sending as regular message")
            // Send URL as a regular message, not as a file
            if joinedChats.contains(chatId) {
                sendMessageImmediately(trimmedMessage, chatId: chatId)
            } else {
                addPendingMessage(trimmedMessage, for: chatId)
                joinChatRoom(chatId: chatId) { [weak self] success in
                    if !success {
                        self?.errorMessage = "Failed to join chat. Please try again."
                        self?.removePendingMessages(for: chatId)
                    }
                }
            }
        } else {
            // Regular message without URLs
            if joinedChats.contains(chatId) {
                sendMessageImmediately(trimmedMessage, chatId: chatId)
            } else {
                addPendingMessage(trimmedMessage, for: chatId)
                joinChatRoom(chatId: chatId) { [weak self] success in
                    if !success {
                        self?.errorMessage = "Failed to join chat. Please try again."
                        self?.removePendingMessages(for: chatId)
                    }
                }
            }
        }
        
        moveChatToTop(chatId: chatId)
    }
    
    // MARK: - Blocked Message Handling

    private func handleBlockedMessage(_ errorMessage: String) {
        print("🚫 Handling blocked message: \(errorMessage)")
        
        // Determine if it's a URL or file block
        let isURLBlock = errorMessage.contains("The URL") || errorMessage.contains("URL is flagged") || errorMessage.contains("flagged as malicious")
        let isFileBlock = errorMessage.contains("File") || errorMessage.contains("file") || errorMessage.contains("virus") || errorMessage.contains("malware")
        
        if isURLBlock {
            // Extract URL from error message
            let urlPattern = "https?://[^\\s]+"
            if let urlRange = errorMessage.range(of: urlPattern, options: .regularExpression) {
                let blockedURL = String(errorMessage[urlRange])
                print("🚫 URL blocked: \(blockedURL)")
                
                // Create blocked URL info
                let blockedInfo = BlockedMessageInfo(
                    messageId: -1,
                    text: blockedURL,
                    sender: getCurrentUsername(),
                    timestamp: Date(),
                    reason: errorMessage
                )
                
                if let signalR = signalRService as? SignalRService {
                    signalR.addBlockedMessage(blockedInfo)
                }
                
                // Show URL-specific alert
                showURLBlockedAlert(errorMessage, url: blockedURL)
            }
        } else if isFileBlock {
            // Handle file block
            let blockedInfo = BlockedMessageInfo(
                messageId: -1,
                text: extractTextFromErrorMessage(errorMessage),
                sender: getCurrentUsername(),
                timestamp: Date(),
                reason: errorMessage
            )
            
            if let signalR = signalRService as? SignalRService {
                signalR.addBlockedMessage(blockedInfo)
            }
            
            showBlockedMessageAlert(errorMessage)
        } else {
            // Generic block
            showBlockedMessageAlert(errorMessage)
        }
        
        // Remove any optimistic messages that might have been added
        removeRecentOptimisticMessage()
    }

    private func showURLBlockedAlert(_ message: String, url: String? = nil) {
        let alertMessage: String
        if let url = url {
            alertMessage = "⚠️ URL Blocked\n\nURL: \(url)\n\nReason: \(message.replacingOccurrences(of: "⚠️ Message blocked: ", with: ""))"
        } else {
            alertMessage = message
        }
        
        DispatchQueue.main.async {
            self.errorMessage = alertMessage
            
            // Show alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "URL Blocked",
                    message: alertMessage,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootViewController.present(alert, animated: true)
            }
        }
    }

    private func extractTextFromErrorMessage(_ error: String) -> String {
        // Extract URL or text from error message
        if let urlRange = error.range(of: "https?://[^\\s]+", options: .regularExpression) {
            return String(error[urlRange])
        }
        
        if let textRange = error.range(of: "\"(.*?)\"", options: .regularExpression) {
            let text = String(error[textRange])
            return String(text.dropFirst().dropLast()) // Remove quotes
        }
        
        return error
    }
    private func sendMessageImmediately(_ text: String, chatId: Int) {
        let tempMessageId = addOptimisticMessage(text, chatId: chatId)
        moveChatToTop(chatId: chatId)
        
        // Send as text message with type .text and fileSize 0
        signalRService.sendMessage(
            text,
            chatId: chatId,
            fileUrl: nil,
            fileName: nil,
            fileSize: 0,  // Send 0 for text messages as backend expects
            fileExtension: nil,
            type: .text
        )
    }
    
    // Update addOptimisticMessage method
    private func addOptimisticMessage(_ text: String, chatId: Int) -> Int {
        let tempMessageId = -Int.random(in: 1000000...9999999)
        let optimisticMessage = Message(
            id: tempMessageId,
                        displayText: text,
            name: getCurrentUsername(),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            isRead: true
        )
        
        print("📝 Adding optimistic message with ID \(tempMessageId)")
        optimisticMessageTracking[tempMessageId] = text
        
        if var currentChat = currentChat, currentChat.id == chatId {
            var updatedMessages = currentChat.messages
            updatedMessages.append(optimisticMessage)
            updatedMessages = sortMessagesByDate(updatedMessages) // ← ASCENDING sort
            
            self.currentChat = Chat(
                id: currentChat.id,
                name: currentChat.name,
                pictureUrl: currentChat.pictureUrl,
                type: currentChat.type,
                messages: updatedMessages,
                users: currentChat.users,
                unreadCount: 0,
                isOnline: currentChat.isOnline
            )
        }
        
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            var updatedMessages = updatedChat.messages
            updatedMessages.append(optimisticMessage)
            updatedMessages = sortMessagesByDate(updatedMessages) // ← ASCENDING sort
            
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: updatedMessages,
                users: updatedChat.users,
                unreadCount: 0,
                isOnline: updatedChat.isOnline
            )
            chats[index] = updatedChat
            saveChats()
        }
        
        return tempMessageId
    }
    
    private func replaceOptimisticMessage(_ receivedMessage: ReceivedPrivateMessage, chatId: Int) {
        // ✅ SAFETY CHECK FIRST - Don't replace if it's an unsafe file
        if receivedMessage.isFile == true && receivedMessage.isSafe == false {
            print("🚫 SKIPPING replaceOptimisticMessage for blocked file: \(receivedMessage.fileUrl ?? "unknown")")
            return
        }
        
        guard let receivedText = receivedMessage.text else {
            print("⚠️ Cannot replace - missing text")
            return
        }
        
        let receivedMessageId = receivedMessage.actualMessageId
        guard receivedMessageId > 0 else {
            print("⚠️ Cannot replace - invalid message ID: \(receivedMessageId)")
            return
        }
        
        print("🔄 REPLACING: Looking for optimistic message matching text: '\(receivedText)'")
        print("   Real message ID from server: \(receivedMessageId)")
        print("   In chat: \(chatId)")
        
        let realMessage = receivedMessage.toMessage()
        
        // Method 1: Find by matching text in our tracking dictionary
        var tempMessageIdToRemove: Int? = nil
        
        for (tempId, trackedText) in optimisticMessageTracking {
            if trackedText == receivedText {
                print("✅ Found matching optimistic message with temp ID: \(tempId)")
                tempMessageIdToRemove = tempId
                break
            }
        }
        
        // Method 2: If not found, look in current chat messages
        if tempMessageIdToRemove == nil {
            print("⚠️ Not found in tracking - searching in chat messages...")
            
            // Update current chat
            if var currentChat = currentChat, currentChat.id == chatId {
                var messages = currentChat.messages
                
                // Find the MOST RECENT optimistic message with matching text
                let optimisticMessages = messages.filter { $0.id < 0 }
                for optimisticMsg in optimisticMessages.reversed() {
                    if optimisticMsg.displayText == receivedText && isCurrentUser(message: optimisticMsg) {
                        print("✅ Found optimistic message in current chat: \(optimisticMsg.id)")
                        tempMessageIdToRemove = optimisticMsg.id
                        break
                    }
                }
                
                // Remove the optimistic message
                if let tempId = tempMessageIdToRemove {
                    messages.removeAll { $0.id == tempId }
                    print("✅ Removed optimistic message \(tempId)")
                }
                
                // Add real message if not already there
                if !messages.contains(where: { $0.id == receivedMessageId }) {
                    messages.append(realMessage)
                    messages.sort { $0.date > $1.date }
                    print("✅ Added real message ID \(receivedMessageId)")
                }
                
                self.currentChat = Chat(
                    id: currentChat.id,
                    name: currentChat.name,
                    pictureUrl: currentChat.pictureUrl,
                    type: currentChat.type,
                    messages: messages,
                    users: currentChat.users,
                    unreadCount: 0,
                    isOnline: currentChat.isOnline
                )
            }
        }
        
        // Update in chats list
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            var messages = updatedChat.messages
            
            // If we found the temp ID, remove it
            if let tempId = tempMessageIdToRemove {
                messages.removeAll { $0.id == tempId }
                optimisticMessageTracking.removeValue(forKey: tempId)
                print("✅ Removed from chats list: optimistic message \(tempId)")
            } else {
                // Otherwise, remove any optimistic messages with matching text
                messages.removeAll { msg in
                    msg.id < 0 && msg.displayText == receivedText && isCurrentUser(message: msg)
                }
            }
            
            // Add real message if not already there
            if !messages.contains(where: { $0.id == receivedMessageId }) {
                messages.append(realMessage)
                messages.sort { $0.date > $1.date }
                print("✅ Added real message to chats list")
            }
            
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: messages,
                users: updatedChat.users,
                unreadCount: 0,
                isOnline: updatedChat.isOnline
            )
            chats[index] = updatedChat
            saveChats()
            
            // Notify UI
            notifyChatsUpdated()
        }
        
        print("✅ Replacement complete for message ID \(receivedMessageId)")
    }
    
    // ✅ FIXED: Process incoming messages and wait for FileStatusUpdated
    private func processIncomingRealTimeMessage(_ receivedMessage: ReceivedPrivateMessage) {
        let messageId = generateMessageId(receivedMessage)
        if processedMessageIds.contains(messageId) {
            print("⏭️ SKIPPING DUPLICATE message (already processed)")
            return
        }
        
        processedMessageIds.insert(messageId)
        
        if processedMessageIds.count > 100 {
            let toRemove = processedMessageIds.count - 100
            processedMessageIds = Set(processedMessageIds.dropFirst(toRemove))
        }
        
        // ✅ Handle file scanning - DON'T block on initial isSafe: false
        // The server sends isSafe: false as a pending state, then FileStatusUpdated has the real result
        if receivedMessage.isFile == true {
            let ext = (receivedMessage.extension ?? "").lowercased()
            let audioExtensions = ["m4a", "mp3", "wav", "aac", "ogg", "caf", "aiff"]
            let isVoice = audioExtensions.contains(ext)
            
            if isVoice {
                print("🎙️ Voice message - processing normally (no scan needed)")
                // Continue to normal processing for voice messages
            } else if receivedMessage.isSafe == false {
                // File is being scanned - DON'T block, wait for FileStatusUpdated
                print("⏳ File isSafe=false on echo (pending scan) - waiting for FileStatusUpdated to confirm")
                // Continue to normal processing - DO NOT RETURN HERE
            } else {
                print("📁 File is safe from echo - processing normally")
            }
            // IMPORTANT: Continue processing - do NOT return early
        }
        
        // Continue with normal processing for safe files
        let currentUsername = getCurrentUsername()
        let isFromCurrentUser = receivedMessage.from?.lowercased() == "you" ||
                               receivedMessage.from?.lowercased() == currentUsername.lowercased()
        
        var effectiveChatId = receivedMessage.chatId ?? 0
        
        if effectiveChatId == 0 {
            if let signalR = signalRService as? SignalRService {
                effectiveChatId = signalR.lastSentChatId ?? 0
            }
        }
        
        guard effectiveChatId > 0 else {
            print("⚠️ Cannot process - invalid chatId")
            return
        }
        
        if isFromCurrentUser {
            print("🔄 Processing OWN message echo - replacing optimistic message IMMEDIATELY")
            DispatchQueue.main.async { [weak self] in
                self?.replaceOptimisticMessageImmediately(receivedMessage, chatId: effectiveChatId)
            }
        } else {
            print("🔄 Processing OTHER user's message")
            handleOtherUserMessage(receivedMessage, effectiveChatId: effectiveChatId)
        }
    }
    private func showBlockedFileAlertWithFileName(_ fileName: String, chatId: Int) {
        let message = "⚠️ File Blocked\n\nThe file \"\(fileName)\" was blocked by our security system and was not delivered to protect you from potential malware."
        
        DispatchQueue.main.async {
            self.errorMessage = message
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "File Blocked",
                    message: message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootViewController.present(alert, animated: true)
            }
        }
    }
      
    private func replaceOptimisticMessageImmediately(_ receivedMessage: ReceivedPrivateMessage, chatId: Int) {
        // ✅ SAFETY CHECK: Don't replace if it's an unsafe file
        if receivedMessage.isFile == true && receivedMessage.isSafe == false {
            print("🚫 SKIPPING replaceOptimisticMessageImmediately for blocked file")
            return
        }
        
        guard let receivedText = receivedMessage.text else { return }
        let receivedMessageId = receivedMessage.actualMessageId
        guard receivedMessageId > 0 else { return }
        
        print("🔄 IMMEDIATE REPLACE: text='\(receivedText)', realID=\(receivedMessageId)")
        
        let realMessage = receivedMessage.toMessage()
        var tempMessageIdToRemove: Int? = nil
        
        // Find matching optimistic message
        for (tempId, trackedText) in optimisticMessageTracking {
            if trackedText == receivedText {
                tempMessageIdToRemove = tempId
                break
            }
        }
        
        // Update current chat
        if var currentChat = currentChat, currentChat.id == chatId {
            var messages = currentChat.messages
            
            // Remove optimistic message if found
            if let tempId = tempMessageIdToRemove {
                messages.removeAll { $0.id == tempId }
                optimisticMessageTracking.removeValue(forKey: tempId)
            }
            
            // Add real message if not already there
            if !messages.contains(where: { $0.id == receivedMessageId }) {
                messages.append(realMessage)
            }
            
            messages = sortMessagesByDate(messages)
            
            self.currentChat = Chat(
                id: currentChat.id,
                name: currentChat.name,
                pictureUrl: currentChat.pictureUrl,
                type: currentChat.type,
                messages: messages,
                users: currentChat.users,
                unreadCount: 0,
                isOnline: currentChat.isOnline
            )
        }
        
        // Update chats list
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            var messages = updatedChat.messages
            
            if let tempId = tempMessageIdToRemove {
                messages.removeAll { $0.id == tempId }
            }
            
            if !messages.contains(where: { $0.id == receivedMessageId }) {
                messages.append(realMessage)
            }
            
            messages = sortMessagesByDate(messages)
            
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: messages,
                users: updatedChat.users,
                unreadCount: 0,
                isOnline: updatedChat.isOnline
            )
            chats[index] = updatedChat
            saveChats()
        }
        
        messageDeliveryStatus[receivedMessageId] = true
        notifyChatsUpdated()
        print("✅ Optimistic message replaced IMMEDIATELY")
    }
    private func handleOwnMessageEcho(_ receivedMessage: ReceivedPrivateMessage, chatId: Int) {
        guard chatId > 0 else {
            print("⚠️ Skipping own message echo - invalid chatId: \(chatId)")
            return
        }
        
        print("✅ Processing own message echo - replacing optimistic message")
        replaceOptimisticMessage(receivedMessage, chatId: chatId)
    }

    // FIXED: Single path for handling other user's messages
    private func handleOtherUserMessage(_ receivedMessage: ReceivedPrivateMessage, effectiveChatId: Int) {
        let newMessage = receivedMessage.toMessage()
        
        guard effectiveChatId > 0 else {
            print("❌ Cannot process other user message - invalid chatId")
            return
        }
        
        // Check if chat exists
        if let index = chats.firstIndex(where: { $0.id == effectiveChatId }) {
            // Chat exists - add message to it
            addMessageToExistingChat(newMessage, at: index, chatId: effectiveChatId)
        } else {
            // Chat doesn't exist - fetch it from server
            print("⚠️ Received message for unknown chat \(effectiveChatId) - fetching from server")
            loadChatAndAddMessage(chatId: effectiveChatId, message: newMessage, senderName: receivedMessage.from ?? "")
        }
    }
    private func addMessageToExistingChat(_ message: Message, at index: Int, chatId: Int) {
        var updatedChat = chats[index]
        
        // Check for duplicates
        let isDuplicate = updatedChat.messages.contains { existingMessage in
            existingMessage.id == message.id ||
            (existingMessage.displayText == message.displayText &&
             existingMessage.name == message.name &&
             abs(existingMessage.date.timeIntervalSince(message.date)) < 5)
        }
        
        guard !isDuplicate else {
            print("⏭️ Skipping duplicate message in chat \(chatId)")
            return
        }
        var updatedMessages = updatedChat.messages
         updatedMessages.append(message)
        
        // SORT messages ASCENDING (oldest first, newest last)
         updatedMessages = sortMessagesByDate(updatedMessages)
        // Calculate unread count
        let isCurrentlyViewing = currentChatId == chatId
        let isFromCurrentUser = isCurrentUser(message: message)
        
        // Only increment if: (1) not from current user AND (2) not currently viewing
        let newUnreadCount = (!isFromCurrentUser && !isCurrentlyViewing)
            ? updatedChat.unreadCount + 1
            : updatedChat.unreadCount
        
        print("💬 Adding message to chat \(chatId): unread=\(newUnreadCount), viewing=\(isCurrentlyViewing), fromSelf=\(isFromCurrentUser)")
        
        let finalChat = Chat(
            id: updatedChat.id,
            name: updatedChat.name,
            pictureUrl: updatedChat.pictureUrl,
            type: updatedChat.type,
            messages: updatedMessages,
            users: updatedChat.users,
            unreadCount: newUnreadCount,
            isOnline: updatedChat.isOnline
        )
        
        chats[index] = finalChat
        
        // Update currentChat if viewing this chat
        if currentChat?.id == chatId {
            currentChat = finalChat
        }
        
        // Move to top and save
        moveChatToTop(chatId: chatId)
        saveChats()
        
        // ⚠️ CRITICAL: Notify that chats have been updated
        notifyChatsUpdated()
        
        // Mark as read if currently viewing and not from self
        if isCurrentlyViewing && !isFromCurrentUser {
            markChatAsRead(chatId: chatId)
        }
    }
    
    // In handleMessageHistory method
    private func handleMessageHistory(_ messages: [ReceivedPrivateMessage]) {
        guard !messages.isEmpty, let firstMessage = messages.first else { return }
        
        let chatId = firstMessage.id
        let messageObjects = messages.map { $0.toMessage() }
        
        // Sort message history in ASCENDING order
        let sortedMessages = sortMessagesByDate(messageObjects)
        
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: sortedMessages, // ← Use sorted messages
                users: updatedChat.users,
                unreadCount: updatedChat.unreadCount,
                isOnline: updatedChat.isOnline
            )
            chats[index] = updatedChat
            
            if currentChat?.id == chatId {
                currentChat = updatedChat
            }
        } else {
            let newChat = Chat(
                id: chatId,
                name: firstMessage.name,
                pictureUrl: "/uploads/users/default.png",
                type: 1,
                messages: sortedMessages, // ← Use sorted messages
                users: [],
                unreadCount: 0,
                isOnline: false
            )
            chats.insert(newChat, at: 0)
        }
        
        saveChats()
    }
    
    // MARK: - HTTP API Methods
    
    func loadAllUsers() {
        isLoading = true
        errorMessage = nil
        
        getAllUsersService.getAllUsers()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load users: \(error.localizedDescription)"
                    print("failed to load users error: \(error.localizedDescription)Z")
                }
            } receiveValue: { [weak self] users in
                self?.users = users
            }
            .store(in: &cancellables)
    }
    
    func loadChat(chatId: Int) {
        isLoading = true
        errorMessage = nil
        
        networkService.getChat(chatId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
//                    self?.errorMessage = "Failed to load chat: \(error.localizedDescription)"
                    print("failed to load users error: \(error.localizedDescription)Z")

                }
            } receiveValue: { [weak self] chat in
                self?.currentChat = chat
                
                if let index = self?.chats.firstIndex(where: { $0.id == chat.id }) {
                    self?.chats[index] = chat
                    self?.saveChats()
                }
                
                self?.markChatAsRead(chatId: chatId)
            }
            .store(in: &cancellables)
    }
    
    func createPrivateChat(with userId: String) {
        isLoading = true
        errorMessage = nil
        
        PrivateChatService.shared.createPrivateChat(with: userId)
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to create chat: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] (response: ChatResponse) in
                self?.chats.removeAll { $0.id == response.chatData.id }
                self?.chats.insert(response.chatData, at: 0)
                self?.currentChat = response.chatData
                self?.saveChats()
                self?.joinChatRoom(chatId: response.chatData.id)
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Local Storage (Cache)
    
     func saveChats() {
        if let encoded = try? JSONEncoder().encode(chats) {
            let username = getCurrentUsername()
            UserDefaults.standard.set(encoded, forKey: "chats_\(username)")
            print("💾 Saved \(chats.count) chats to cache")
        }
    }
    
    func loadSavedChats() {
        let username = getCurrentUsername()
        if let savedChatsData = UserDefaults.standard.data(forKey: "chats_\(username)"),
           let savedChats = try? JSONDecoder().decode([Chat].self, from: savedChatsData) {
            self.chats = savedChats.sorted { $0.lastMessageDate > $1.lastMessageDate }
            print("💾 Loaded \(chats.count) cached chats")
        } else {
            self.chats = []
            print("💾 No cached chats found")
        }
    }
    
    // MARK: - Helper Methods
    
    func getCurrentUsername() -> String {
        if let authUser = UserDefaults.standard.string(forKey: "currentUsername") {
            return authUser
        }
        if let displayName = UserDefaults.standard.string(forKey: "userDisplayName") {
            return displayName
        }
        if let userName = UserDefaults.standard.string(forKey: "userName") {
            return userName
        }
        return "UnknownUser"
    }
    
    func getCurrentUserId() -> String {
        if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
            return userId
        }
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            return userId
        }
        if let username = UserDefaults.standard.string(forKey: "currentUsername") {
            return username
        }
        return "unknown"
    }
    
    func isCurrentUser(message: Message) -> Bool {
        let currentUsername = getCurrentUsername()
        let messageNameNormalized = message.name.trimmingCharacters(in: .whitespaces).lowercased()
        let currentNameNormalized = currentUsername.trimmingCharacters(in: .whitespaces).lowercased()
        
        return messageNameNormalized == currentNameNormalized ||
               messageNameNormalized == "you" ||
               (currentUsername.lowercased() == "test46" && messageNameNormalized == "you")
    }
    
    func hasChatWithUser(userId: String) -> Bool {
        let currentUserId = getCurrentUserId()
        
        return chats.contains { chat in
            guard chat.type == 1 else { return false }
            let userIdsInChat = chat.users.map { $0.userId }
            return userIdsInChat.contains(currentUserId) && userIdsInChat.contains(userId)
        }
    }
    
    func sendImageMessage(_ image: UIImage, chatId: Int) {
        isLoading = true
        
        let tempMessageId = -Int.random(in: 1000000...9999999)
        let tempMessage = Message(
            id: tempMessageId,
                        displayText: "📤 Uploading image...",
            name: getCurrentUsername(),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            isRead: false
        )
        
        // Add temporary message
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            var updatedMessages = updatedChat.messages
            updatedMessages.append(tempMessage)
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: updatedMessages,
                users: updatedChat.users,
                unreadCount: updatedChat.unreadCount,
                isOnline: updatedChat.isOnline
            )
            chats[index] = updatedChat
            saveChats()
        }
        
        ImageUploadService.shared.uploadImage(image) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ Image uploaded: \(response.url)")
                    
                    // Remove temporary message
                    if let index = self?.chats.firstIndex(where: { $0.id == chatId }) {
                        var updatedChat = self?.chats[index] ?? self?.chats[index]
                        var messages = updatedChat?.messages ?? []
                        messages.removeAll { $0.id == tempMessageId }
                        
                        updatedChat = Chat(
                            id: updatedChat?.id ?? chatId,
                            name: updatedChat?.name ?? "",
                            pictureUrl: updatedChat?.pictureUrl ?? "",
                            type: updatedChat?.type ?? 1,
                            messages: messages,
                            users: updatedChat?.users ?? [],
                            unreadCount: updatedChat?.unreadCount ?? 0,
                            isOnline: updatedChat?.isOnline ?? false
                        )
                        self?.chats[index] = updatedChat!
                        self?.saveChats()
                    }
                    
                    // Extract file info
                    let fileName = (response.url as NSString).lastPathComponent
                    let fileExtension = (fileName as NSString).pathExtension.lowercased()
                    let imageData = image.jpegData(compressionQuality: 0.8)
                    let fileSize = Int64(imageData?.count ?? 0)
                    
                    // Send with proper parameters
                    self?.signalRService.sendMessage(
                        response.url,
                        chatId: chatId,
                        fileUrl: response.url,
                        fileName: fileName,
                        fileSize: fileSize,
                        fileExtension: fileExtension,
                        type: .image
                    )
                    
                case .failure(let error):
                    print("❌ Image upload failed: \(error)")
                    self?.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    
                    // Update temporary message to show error
                    if let index = self?.chats.firstIndex(where: { $0.id == chatId }) {
                        var updatedChat = self?.chats[index] ?? self?.chats[index]
                        var messages = updatedChat?.messages ?? []
                        
                        if let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                            messages[tempIndex] = Message(
                                id: tempMessageId,
                                            displayText: "❌ Failed to upload image",
                                name: self?.getCurrentUsername() ?? "You",
                                timestamp: ISO8601DateFormatter().string(from: Date()),
                                isRead: false
                            )
                            
                            updatedChat = Chat(
                                id: updatedChat?.id ?? chatId,
                                name: updatedChat?.name ?? "",
                                pictureUrl: updatedChat?.pictureUrl ?? "",
                                type: updatedChat?.type ?? 1,
                                messages: messages,
                                users: updatedChat?.users ?? [],
                                unreadCount: updatedChat?.unreadCount ?? 0,
                                isOnline: updatedChat?.isOnline ?? false
                            )
                            self?.chats[index] = updatedChat!
                            self?.saveChats()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - UI Lifecycle
    
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
    
    private func ensureSignalRConnection() {
        guard !isSignalRConnected else { return }
        connectSignalR()
    }
    
    func startPollingForChat(chatId: Int) {
        currentChatId = chatId
        stopPolling()
        markChatAsRead(chatId: chatId)
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshChat(chatId: chatId)
        }
    }
    
    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        currentChatId = nil
    }
    
    private func refreshChat(chatId: Int) {
        networkService.getChat(chatId)
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] chat in
                self?.currentChat = chat
                
                if let index = self?.chats.firstIndex(where: { $0.id == chat.id }) {
                    self?.chats[index] = chat
                    self?.saveChats()
                }
            }
            .store(in: &cancellables)
    }
    
//    // MARK: - Private Helpers
//    
//    private func moveChatToTop(chatId: Int) {
//        if let index = chats.firstIndex(where: { $0.id == chatId }) {
//            let chat = chats.remove(at: index)
//            chats.insert(chat, at: 0)
//            saveChats()
//        }
//    }
    
    private func loadChatAndAddMessage(chatId: Int, message: Message, senderName: String) {
        networkService.getChat(chatId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure = completion {
                    self?.createTemporaryChatForMessage(chatId: chatId, message: message, senderName: senderName)
                }
            } receiveValue: { [weak self] chat in
                guard let self = self else { return }
                
                if let existingIndex = self.chats.firstIndex(where: { $0.id == chatId }) {
                    self.addMessageToExistingChat(message, at: existingIndex, chatId: chatId)
                } else {
                    var messages = chat.messages
                    messages.append(message)
                    messages.sort { $0.date > $1.date }
                    
                    let updatedChat = Chat(
                        id: chat.id,
                        name: chat.name,
                        pictureUrl: chat.pictureUrl,
                        type: chat.type,
                        messages: messages,
                        users: chat.users,
                        unreadCount: 1,
                        isOnline: chat.isOnline
                    )
                    
                    self.chats.insert(updatedChat, at: 0)
                    self.saveChats()
                    self.joinChatRoom(chatId: chatId)
                }
            }
            .store(in: &cancellables)
    }
    
    private func createTemporaryChatForMessage(chatId: Int, message: Message, senderName: String) {
        guard chatId > 0 else {
            print("⚠️ Skipping temporary chat creation - invalid chatId: \(chatId)")
            return
        }
        
        let temporaryChat = Chat(
            id: chatId,
            name: senderName,
            pictureUrl: "/uploads/users/default.png",
            type: 1,
            messages: [message],
            users: [],
            unreadCount: 1,
            isOnline: false
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.chats.insert(temporaryChat, at: 0)
            self?.saveChats()
            self?.joinChatRoom(chatId: chatId)
        }
    }
    
    private func addPendingMessage(_ message: String, for chatId: Int) {
        let key = "\(chatId)_\(Date().timeIntervalSince1970)"
        pendingMessages[key] = (message: message, chatId: chatId)
    }
    
    private func processPendingMessages(for chatId: Int) {
        let messagesToSend = pendingMessages.filter { $0.value.chatId == chatId }
        
        for (key, pending) in messagesToSend {
            sendMessageImmediately(pending.message, chatId: chatId)
            pendingMessages.removeValue(forKey: key)
        }
    }
    
    private func removePendingMessages(for chatId: Int) {
        pendingMessages = pendingMessages.filter { $0.value.chatId != chatId }
    }
    
    private func generateMessageId(_ message: ReceivedPrivateMessage) -> String {
        return "\(message.from ?? "")_\(message.text ?? "")_\(message.timeStamp ?? "")_\(message.chatId ?? 0)"
    }
    // Update this whenever chats change
     func notifyChatsUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.chatsUpdated = Date()
        }
    }
   
    
    // ✅ ADD THIS: Handle ALL messages seen in a chat
    private func handleAllMessagesSeenInChat(chatId: Int, userName: String) {
        let currentUsername = getCurrentUsername()
        
        guard userName.lowercased() != currentUsername.lowercased() else {
            print("👁️ Ignoring our own seen status")
            return
        }
        
        print("👁️ \(userName) saw ALL messages in chat \(chatId)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let chatIndex = self.chats.firstIndex(where: { $0.id == chatId }) {
                var updatedChat = self.chats[chatIndex]
                var updatedMessages = updatedChat.messages
                var hasChanges = false
                
                // Mark ALL messages from current user as seen
                for (index, message) in updatedMessages.enumerated() {
                    // Only mark our own messages
                    if self.isCurrentUser(message: message) {
                        var seenBy = message.seenBy ?? []
                        
                        if !seenBy.contains(userName) {
                            seenBy.append(userName)
                            hasChanges = true
                            
                            // Update in-memory tracking
                            if self.messageSeenStatus[message.id] == nil {
                                self.messageSeenStatus[message.id] = []
                            }
                            if !self.messageSeenStatus[message.id]!.contains(userName) {
                                self.messageSeenStatus[message.id]!.append(userName)
                            }
                            
                            updatedMessages[index] = Message(
                                id: message.id,
                                            displayText: message.displayText,
                                name: message.name,
                                timestamp: message.timestamp,
                                isRead: true,
                                seenBy: seenBy
                            )
                            
                            print("👁️ ✅ Message \(message.id) marked as seen by \(userName)")
                        }
                    }
                }
                
                if hasChanges {
                    updatedChat = Chat(
                        id: updatedChat.id,
                        name: updatedChat.name,
                        pictureUrl: updatedChat.pictureUrl,
                        type: updatedChat.type,
                        messages: updatedMessages,
                        users: updatedChat.users,
                        unreadCount: updatedChat.unreadCount,
                        isOnline: updatedChat.isOnline
                    )
                    
                    self.chats[chatIndex] = updatedChat
                    
                    if self.currentChat?.id == chatId {
                        self.currentChat = updatedChat
                    }
                    
                    self.saveChats()
                    self.notifyChatsUpdated()
                    
                    print("👁️ ✅ Updated ALL messages in chat \(chatId)")
                }
            }
        }
    }
    
   
        
        // ✅ Update markVisibleMessagesAsSeen - just handle locally since server doesn't support it
        func markVisibleMessagesAsSeen(chatId: Int, messageIds: [Int]) {
            print("👁️ We saw \(messageIds.count) messages in chat \(chatId)")
            
            // Just update local tracking for OUR view of THEIR messages
            for messageId in messageIds {
                if messageSeenStatus[messageId] == nil {
                    messageSeenStatus[messageId] = []
                }
                
                let currentUser = getCurrentUsername()
                if !messageSeenStatus[messageId]!.contains(currentUser) {
                    messageSeenStatus[messageId]!.append(currentUser)
                }
            }
        }
    // ✅ FIXED: Update delivery status when partner is online
        private func handleUserStatusChange(_ userStatus: UserStatus) {
            print("👤 User status changed: \(userStatus.userName) is \(userStatus.isOnline ? "online" : "offline")")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.userStatuses[userStatus.userName] = userStatus.isOnline
                
                // ✅ If user came online, mark undelivered messages as delivered
                if userStatus.isOnline, let chatIndex = self.chats.firstIndex(where: { $0.name == userStatus.userName && $0.type == 1 }) {
                    let chat = self.chats[chatIndex]
                    
                    // Mark all sent messages as delivered
                    for message in chat.messages where self.isCurrentUser(message: message) {
                        self.messageDeliveryStatus[message.id] = true
                    }
                }
                
                if let index = self.chats.firstIndex(where: { $0.name == userStatus.userName && $0.type == 1 }) {
                    var updatedChat = self.chats[index]
                    updatedChat = Chat(
                        id: updatedChat.id,
                        name: updatedChat.name,
                        pictureUrl: updatedChat.pictureUrl,
                        type: updatedChat.type,
                        messages: updatedChat.messages,
                        users: updatedChat.users,
                        unreadCount: updatedChat.unreadCount,
                        isOnline: userStatus.isOnline
                    )
                    self.chats[index] = updatedChat
                    self.saveChats()
                    self.notifyChatsUpdated()
                }
            }
        }
        
        private func handleAllMessagesSeen(chatId: Int, userName: String) {
            print("👁️✅ Processing: \(userName) has seen ALL messages in chat \(chatId)")
            
            let currentUsername = getCurrentUsername()
            
            guard userName.lowercased() != currentUsername.lowercased() else {
                print("👁️ Ignoring our own seen status")
                return
            }
            
            guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else {
                print("⚠️ Chat \(chatId) not found")
                return
            }
            
            var updatedChat = chats[chatIndex]
            var hasChanges = false
            var updatedMessages = updatedChat.messages
            
            for i in 0..<updatedMessages.count {
                let message = updatedMessages[i]
                
                if isCurrentUser(message: message) {
                    var seenBy = message.seenBy ?? []
                    
                    if !seenBy.contains(userName) {
                        seenBy.append(userName)
                        hasChanges = true
                        
                        // ✅ Also mark as delivered
                        messageDeliveryStatus[message.id] = true
                        
                        updatedMessages[i] = Message(
                            id: message.id,
                                        displayText: message.displayText,
                            name: message.name,
                            timestamp: message.timestamp,
                            isRead: true,
                            seenBy: seenBy
                        )
                        
                        if messageSeenStatus[message.id] == nil {
                            messageSeenStatus[message.id] = []
                        }
                        if !messageSeenStatus[message.id]!.contains(userName) {
                            messageSeenStatus[message.id]!.append(userName)
                        }
                        
                        print("👁️✅ Message \(message.id) marked as seen by \(userName)")
                    }
                }
            }
            
            if hasChanges {
                updatedChat = Chat(
                    id: updatedChat.id,
                    name: updatedChat.name,
                    pictureUrl: updatedChat.pictureUrl,
                    type: updatedChat.type,
                    messages: updatedMessages,
                    users: updatedChat.users,
                    unreadCount: updatedChat.unreadCount,
                    isOnline: updatedChat.isOnline
                )
                
                chats[chatIndex] = updatedChat
                
                if currentChat?.id == chatId {
                    currentChat = updatedChat
                }
                
                saveChats()
                notifyChatsUpdated()
            }
        }
        
        // ✅ ADD: Helper to check if message is delivered
        func isMessageDelivered(_ messageId: Int) -> Bool {
            return messageDeliveryStatus[messageId] ?? false
        }
        
      
        
    // ✅ Keep this method: Get seen status for a message
       func getSeenStatus(for messageId: Int) -> [String] {
           return messageSeenStatus[messageId] ?? []
       }
    
    // MARK: - URL Scanning
    private func sendURLMessageWithScan(_ text: String, chatId: Int) {
        // Add optimistic message showing "Scanning link..."
        let tempMessageId = -Int.random(in: 1000000...9999999)
        let scanningMessage = Message(
            id: tempMessageId,
                        displayText: "🔍 Scanning link...",
            name: getCurrentUsername(),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            isRead: false
        )
        
        // Add to chat
        addTemporaryScanningMessage(scanningMessage, chatId: chatId)
        
        // Send to server for scanning - it will be sent as TEXT, not a file
        if let signalR = signalRService as? SignalRService {
            signalR.sendMessageWithScan(text, chatId: chatId, isFile: false)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ URL scan failed: \(error)")
                        self?.handleURLScanFailure(tempMessageId: tempMessageId, chatId: chatId, error: error)
                    }
                }, receiveValue: { [weak self] scanResult in
                    if let scanResult = scanResult {
                        if !scanResult.isSafe {
                            print("⚠️ URL blocked: \(scanResult.message)")
                            self?.handleBlockedURL(tempMessageId: tempMessageId, chatId: chatId, url: text, reason: scanResult.message)
                        } else {
                            print("✅ URL passed scan - will be sent as clickable link")
                            // Remove scanning message - the real message will come via SignalR
                            self?.removeTemporaryScanningMessage(tempMessageId, chatId: chatId)
                        }
                    } else {
                        // Remove scanning message - the real message will come via SignalR
                        self?.removeTemporaryScanningMessage(tempMessageId, chatId: chatId)
                    }
                })
                .store(in: &cancellables)
        }
    }

    private func addTemporaryScanningMessage(_ message: Message, chatId: Int) {
        if var currentChat = currentChat, currentChat.id == chatId {
            var updatedMessages = currentChat.messages
            updatedMessages.append(message)
            updatedMessages = sortMessagesByDate(updatedMessages)
            
            self.currentChat = Chat(
                id: currentChat.id,
                name: currentChat.name,
                pictureUrl: currentChat.pictureUrl,
                type: currentChat.type,
                messages: updatedMessages,
                users: currentChat.users,
                unreadCount: 0,
                isOnline: currentChat.isOnline
            )
        }
        
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            var updatedMessages = updatedChat.messages
            updatedMessages.append(message)
            updatedMessages = sortMessagesByDate(updatedMessages)
            
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: updatedMessages,
                users: updatedChat.users,
                unreadCount: 0,
                isOnline: updatedChat.isOnline
            )
            chats[index] = updatedChat
            saveChats()
        }
    }

    private func removeTemporaryScanningMessage(_ tempMessageId: Int, chatId: Int) {
        if var currentChat = currentChat, currentChat.id == chatId {
            var messages = currentChat.messages
            messages.removeAll { $0.id == tempMessageId }
            messages = sortMessagesByDate(messages)
            
            self.currentChat = Chat(
                id: currentChat.id,
                name: currentChat.name,
                pictureUrl: currentChat.pictureUrl,
                type: currentChat.type,
                messages: messages,
                users: currentChat.users,
                unreadCount: 0,
                isOnline: currentChat.isOnline
            )
        }
        
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            var messages = updatedChat.messages
            messages.removeAll { $0.id == tempMessageId }
            messages = sortMessagesByDate(messages)
            
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: messages,
                users: updatedChat.users,
                unreadCount: 0,
                isOnline: updatedChat.isOnline
            )
            chats[index] = updatedChat
            saveChats()
        }
    }

    private func handleURLScanFailure(tempMessageId: Int, chatId: Int, error: Error) {
        // Replace scanning message with error
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            var messages = updatedChat.messages
            
            if let msgIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                messages[msgIndex] = Message(
                    id: tempMessageId,
                                displayText: "❌ Failed to scan link: \(error.localizedDescription)",
                    name: getCurrentUsername(),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    isRead: false
                )
                
                updatedChat = Chat(
                    id: updatedChat.id,
                    name: updatedChat.name,
                    pictureUrl: updatedChat.pictureUrl,
                    type: updatedChat.type,
                    messages: messages,
                    users: updatedChat.users,
                    unreadCount: 0,
                    isOnline: updatedChat.isOnline
                )
                chats[index] = updatedChat
                saveChats()
            }
        }
    }

    private func handleBlockedURL(tempMessageId: Int, chatId: Int, url: String, reason: String) {
        // Replace scanning message with blocked URL warning
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            var messages = updatedChat.messages
            
            if let msgIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                messages[msgIndex] = Message(
                    id: tempMessageId,
                                displayText: "🚫 BLOCKED LINK: \(url)",
                    name: getCurrentUsername(),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    isRead: false
                )
                
                updatedChat = Chat(
                    id: updatedChat.id,
                    name: updatedChat.name,
                    pictureUrl: updatedChat.pictureUrl,
                    type: updatedChat.type,
                    messages: messages,
                    users: updatedChat.users,
                    unreadCount: 0,
                    isOnline: updatedChat.isOnline
                )
                chats[index] = updatedChat
                saveChats()
            }
        }
        
        // Show alert
        showURLBlockedAlert(reason, url: url)
    }
    }

extension ReceivedPrivateMessage {
    var debugDescription: String {
        return "Message(id: \(id ?? -1), from: \(from ?? "nil"), text: \(text?.prefix(20) ?? "nil")..., chatId: \(chatId ?? 0), time: \(timeStamp ?? "nil"))"
    }
}
// MARK: - Updated ChatViewModel Extension

extension ChatViewModel {
    
    private func handleFileStatusUpdate(_ fileData: FileStatusUpdatedData) {
        print("🔄 Processing file status update for message \(fileData.messageId)")
        
        // Build full URL for the file
        let fullFileUrl: String
        if fileData.fileUrl.hasPrefix("http://") || fileData.fileUrl.hasPrefix("https://") {
            fullFileUrl = fileData.fileUrl
        } else {
            fullFileUrl = "http://158.220.90.131:8444\(fileData.fileUrl)"
        }
        
        print("📁 File URL: \(fullFileUrl)")
        print("📁 File safe: \(fileData.isSafe)")
        print("📁 File name: \(fileData.fileName ?? "unknown")")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var found = false
            
            for (chatIndex, chat) in self.chats.enumerated() {
                var messages = chat.messages
                
                // Find by messageId OR by scanning/uploading placeholder
             
                let targetIndex = messages.firstIndex { msg in
                    msg.id == fileData.messageId          // ← this now works because we set id = realMessageId
                    || (msg.id < 0 && (
                        msg.displayText.hasPrefix("SCANNING:") ||
                        msg.displayText.hasPrefix("UPLOADING:")
                    ))
                }
                
                guard let idx = targetIndex else { continue }
                found = true
                
                if !fileData.isSafe {
                    // BLOCKED - remove the message
                    print("🚫 FILE IS BLOCKED - removing from chat \(chat.id)")
                    messages.remove(at: idx)
                    
                    // Show alert to user
                    self.showBlockedFileAlertWithFileName(fileData.fileName ?? "File", chatId: chat.id)
                } else {
                    // SAFE - replace placeholder with real message
                    print("✅ FILE IS SAFE - showing in chat \(chat.id)")
                    let existingMsg = messages[idx]
                    
                    // Determine correct type based on file extension
                    let fileExtension = (fileData.fileName as NSString?)?.pathExtension.lowercased() ?? ""
                    let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
                    let messageType: MessageType = imageExtensions.contains(fileExtension) ? .image : .file
                    
                    messages[idx] = Message(
                        id: fileData.messageId,
                        displayText: fullFileUrl,
                        name: existingMsg.name,
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        fileUrl: fullFileUrl,
                        type: messageType,
                        isFile: true,
                        fileName: fileData.fileName,
                        fileSize: nil,
                        fileExtension: fileExtension,
                        isSafe: true,
                        isRead: false
                    )
                }
                
                let updatedChat = Chat(
                    id: chat.id,
                    name: chat.name,
                    pictureUrl: chat.pictureUrl,
                    type: chat.type,
                    messages: messages,
                    users: chat.users,
                    unreadCount: chat.unreadCount,
                    isOnline: chat.isOnline
                )
                
                self.chats[chatIndex] = updatedChat
                
                if self.currentChat?.id == chat.id {
                    self.currentChat = updatedChat
                }
                
                self.saveChats()
                self.notifyChatsUpdated()
                break // Found the chat, stop searching
            }
            
            if !found && fileData.isSafe {
                print("⚠️ No scanning placeholder found for safe file - refreshing chat")
                self.notifyChatsUpdated()
            } else if !found && !fileData.isSafe {
                print("⚠️ No message found for blocked file - nothing to remove")
            }
        }
    }
    
    // MARK : - Handle Blocked Messages
   
    
   
    private func removeRecentOptimisticMessage() {
        // Find and remove the most recent optimistic message
        guard let lastOptimisticId = optimisticMessageTracking.keys.max() else { return }
        
        print("🗑️ Removing optimistic message \(lastOptimisticId) due to block")
        
        // Remove from tracking
        optimisticMessageTracking.removeValue(forKey: lastOptimisticId)
        
        // Remove from all chats
        for (chatIndex, chat) in chats.enumerated() {
            var messages = chat.messages
            let initialCount = messages.count
            
            // Remove messages with matching ID
            messages.removeAll { $0.id == lastOptimisticId }
            
            // Check if any were removed
            if messages.count < initialCount {
                let updatedChat = Chat(
                    id: chat.id,
                    name: chat.name,
                    pictureUrl: chat.pictureUrl,
                    type: chat.type,
                    messages: messages,
                    users: chat.users,
                    unreadCount: chat.unreadCount,
                    isOnline: chat.isOnline
                )
                
                chats[chatIndex] = updatedChat
                
                if currentChat?.id == chat.id {
                    currentChat = updatedChat
                }
            }
        }
        
        saveChats()
        notifyChatsUpdated()
    }
    
    // MARK: - Alert Methods
    
    private func showBlockedFileAlert(fileData: FileStatusUpdatedData, sender: String) {
        let alertMessage = "⚠️ File blocked for safety\n\n" +
        "File: \(fileData.fileName ?? fileData.fileUrl)\n" +
        "Sender: \(sender)\n\n" +
        "This file was blocked by our security system."
        
        DispatchQueue.main.async {
            self.errorMessage = alertMessage
            
            // Show alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "File Blocked",
                    message: alertMessage,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootViewController.present(alert, animated: true)
            }
        }
    }
    
    private func showBlockedMessageAlert(_ errorMessage: String) {
        DispatchQueue.main.async {
            self.errorMessage = errorMessage
            
            // Show alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "Message Blocked",
                    message: errorMessage,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootViewController.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - Check if Message is Blocked
    
    func isMessageBlocked(_ messageId: Int) -> Bool {
        guard let signalR = signalRService as? SignalRService else { return false }
        
        // Check if we have a file status update for this message
        if let fileStatus = signalR.fileStatusUpdated, fileStatus.messageId == messageId {
            return !fileStatus.isSafe
        }
        
        // Check blocked messages list
        return signalR.blockedMessages.contains { $0.messageId == messageId }
    }
    
    func getBlockedMessageReason(_ messageId: Int) -> String? {
        guard let signalR = signalRService as? SignalRService else { return nil }
        
        // Find in blocked messages
        return signalR.blockedMessages.first { $0.messageId == messageId }?.reason
    }
    // MARK: - Message History with Seen Status
    
    private func handleMessageHistoryWithSeenStatus(_ messages: [MessageWithSeenStatus]) {
        guard !messages.isEmpty, let firstMessage = messages.first else { return }
        
        let chatId = findChatIdForMessages(messages)
        guard chatId > 0 else {
            print("⚠️ Cannot process message history - no valid chat ID found")
            return
        }
        
        print("📚 Processing \(messages.count) messages with seen status for chat \(chatId)")
        
        // Convert to Message format with seen status
        let messageObjects = messages.map { msg -> Message in
            return Message(
                id: msg.id,
                            displayText: msg.displayText,
                name: msg.from,
                timestamp: msg.timeStamp,
                isRead: msg.isRead,
                seenBy: msg.isRead ? [getPartnerUsername(for: chatId)] : []
            )
        }
        
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            
            // Update message delivery status
            for msg in messages {
                if isMessageFromCurrentUser(msg) {
                    messageDeliveryStatus[msg.id] = msg.isRead ? true : (isPartnerOnline(for: chatId) ? true : false)
                }
            }
            
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: messageObjects,
                users: updatedChat.users,
                unreadCount: calculateUnreadCount(messages),
                isOnline: updatedChat.isOnline
            )
            chats[index] = updatedChat
            
            if currentChat?.id == chatId {
                currentChat = updatedChat
            }
        } else {
            // Create new chat with these messages
            let partnerName = getPartnerUsername(for: chatId)
            let newChat = Chat(
                id: chatId,
                name: partnerName,
                pictureUrl: "/uploads/users/default.png",
                type: 1,
                messages: messageObjects,
                users: [],
                unreadCount: calculateUnreadCount(messages),
                isOnline: isPartnerOnline(for: chatId)
            )
            chats.insert(newChat, at: 0)
        }
        
        saveChats()
        notifyChatsUpdated()
    }
    private func findChatIdForMessages(_ messages: [MessageWithSeenStatus]) -> Int {
        // Try to find chat ID from existing chats based on sender
        for message in messages {
            let sender = message.from
            if let chat = chats.first(where: { $0.name == sender && $0.type == 1 }) {
                return chat.id
            }
        }
        
        // If not found, try to extract from SignalR service
        if let signalR = signalRService as? SignalRService {
            return signalR.lastSentChatId ?? 0
        }
        
        return 0
    }
    
    private func isMessageFromCurrentUser(_ message: MessageWithSeenStatus) -> Bool {
        let currentUsername = getCurrentUsername()
        return message.from.lowercased() == currentUsername.lowercased()
    }
    
    private func getPartnerUsername(for chatId: Int) -> String {
        if let chat = chats.first(where: { $0.id == chatId }) {
            return chat.name
        }
        
        // Extract from current user info
        let currentUsername = getCurrentUsername()
        if let firstMessage = currentChat?.messages.first {
            return firstMessage.name == currentUsername ? "" : firstMessage.name
        }
        
        return ""
    }
    
    private func calculateUnreadCount(_ messages: [MessageWithSeenStatus]) -> Int {
        let currentUsername = getCurrentUsername()
        return messages.filter {
            !$0.isRead && $0.from.lowercased() != currentUsername.lowercased()
        }.count
    }
    
    private func isPartnerOnline(for chatId: Int) -> Bool {
        return userStatuses[getPartnerUsername(for: chatId)] ?? false
    }
    // MARK: - File Scanning Methods
    
    func sendMessageWithScan(_ text: String, chatId: Int, isFile: Bool = false) {
        let trimmedMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        guard isSignalRConnected else {
            errorMessage = "Not connected to chat server. Please check your connection."
            return
        }
        
        if joinedChats.contains(chatId) {
            sendMessageWithScanImmediately(trimmedMessage, chatId: chatId, isFile: isFile)
        } else {
            addPendingMessage(trimmedMessage, for: chatId)
            joinChatRoom(chatId: chatId) { [weak self] success in
                if success {
                    self?.sendMessageWithScanImmediately(trimmedMessage, chatId: chatId, isFile: isFile)
                } else {
                    self?.errorMessage = "Failed to join chat. Please try again."
                    self?.removePendingMessages(for: chatId)
                }
            }
        }
        
        moveChatToTop(chatId: chatId)
    }
    private func removeOptimisticMessage(_ tempMessageId: Int, chatId: Int) {
        print("🗑️ Removing optimistic message \(tempMessageId) from chat \(chatId)")
        
        // Remove from tracking
        optimisticMessageTracking.removeValue(forKey: tempMessageId)
        
        // Remove from current chat
        if var currentChat = currentChat, currentChat.id == chatId {
            var messages = currentChat.messages
            messages.removeAll { $0.id == tempMessageId }
            self.currentChat = Chat(
                id: currentChat.id,
                name: currentChat.name,
                pictureUrl: currentChat.pictureUrl,
                type: currentChat.type,
                messages: messages,
                users: currentChat.users,
                unreadCount: 0,
                isOnline: currentChat.isOnline
            )
        }
        
        // Remove from chats list
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            var messages = updatedChat.messages
            messages.removeAll { $0.id == tempMessageId }
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: messages,
                users: updatedChat.users,
                unreadCount: 0,
                isOnline: updatedChat.isOnline
            )
            chats[index] = updatedChat
            saveChats()
        }
    }
    private func sendMessageWithScanImmediately(_ text: String, chatId: Int, isFile: Bool = false) {
        let tempMessageId = addOptimisticMessage(text, chatId: chatId)
        moveChatToTop(chatId: chatId)
        
        // Store temporary message ID for reference
        let tempId = tempMessageId
        
        if let signalR = signalRService as? SignalRService {
            signalR.sendMessageWithScan(text, chatId: chatId, isFile: isFile)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ File scan failed: \(error)")
                        self?.errorMessage = "File scan failed: \(error.localizedDescription)"
                        
                        // Remove optimistic message since it failed
                        self?.removeOptimisticMessage(tempId, chatId: chatId)
                    }
                }, receiveValue: { [weak self] scanResult in
                    if let scanResult = scanResult {
                        if !scanResult.isSafe {
                            print("⚠️ File blocked: \(scanResult.message)")
                            self?.errorMessage = "File blocked: \(scanResult.message)"
                            
                            // Remove optimistic message since file was blocked
                            self?.removeOptimisticMessage(tempId, chatId: chatId)
                            
                            // Show alert to user
                            DispatchQueue.main.async {
                                // You might want to show an alert here
                                print("ALERT: File blocked by antivirus: \(scanResult.message)")
                            }
                        } else {
                            print("✅ File passed scan: \(scanResult.message)")
                        }
                    }
                })
                .store(in: &cancellables)
        }
    }
    // Helper to update optimistic message text
    private func updateOptimisticMessage(_ tempMessageId: Int, with newText: String, chatId: Int) {
        // Update tracking
        optimisticMessageTracking[tempMessageId] = newText
        
        // Update in current chat
        if var currentChat = currentChat, currentChat.id == chatId {
            if let index = currentChat.messages.firstIndex(where: { $0.id == tempMessageId }) {
                var updatedMessages = currentChat.messages
                updatedMessages[index] = Message(
                    id: tempMessageId,
                                displayText: newText,
                    name: getCurrentUsername(),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    isRead: true
                )
                
                self.currentChat = Chat(
                    id: currentChat.id,
                    name: currentChat.name,
                    pictureUrl: currentChat.pictureUrl,
                    type: currentChat.type,
                    messages: updatedMessages,
                    users: currentChat.users,
                    unreadCount: 0,
                    isOnline: currentChat.isOnline
                )
            }
        }
        
        // Update in chats list
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            if let msgIndex = updatedChat.messages.firstIndex(where: { $0.id == tempMessageId }) {
                var updatedMessages = updatedChat.messages
                updatedMessages[msgIndex] = Message(
                    id: tempMessageId,
                                displayText: newText,
                    name: getCurrentUsername(),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    isRead: true
                )
                
                updatedChat = Chat(
                    id: updatedChat.id,
                    name: updatedChat.name,
                    pictureUrl: updatedChat.pictureUrl,
                    type: updatedChat.type,
                    messages: updatedMessages,
                    users: updatedChat.users,
                    unreadCount: 0,
                    isOnline: updatedChat.isOnline
                )
                chats[index] = updatedChat
                saveChats()
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func handleErrorMessage(_ error: ErrorMessage) {
        print("❌ SignalR Error: \(error.message)")
        
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = error.message
            
            // If error is related to a specific chat, update that chat
            if let chatId = error.chatId, let index = self?.chats.firstIndex(where: { $0.id == chatId }) {
                print("⚠️ Error related to chat \(chatId)")
                // You might want to update the chat's error state here
            }
            
            // Show error to user
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "Error",
                    message: error.message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                rootViewController.present(alert, animated: true)
            }
        }
    }
    func uploadFileWithSignalR(_ data: Data, fileName: String, chatId: Int) -> AnyPublisher<String, Error> {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            return Fail(error: NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authentication token"]))
                .eraseToAnyPublisher()
        }
        
        let baseUrl = "http://158.220.90.131:8444"
        let uploadUrl = "\(baseUrl)/api/Upload/upload"
        
        return Future<String, Error> { promise in
            var request = URLRequest(url: URL(string: uploadUrl)!)
            request.httpMethod = "POST"
            
            let boundary = UUID().uuidString
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // Add file data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    promise(.failure(NSError(domain: "Upload", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let fileUrl = json["url"] as? String {
                        promise(.success(fileUrl))
                    } else {
                        promise(.failure(NSError(domain: "Upload", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                    }
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
        .eraseToAnyPublisher()
    }
//    // Update the sort helper methods
//    private func sortMessagesByDate(_ messages: [Message]) -> [Message] {
//        // Change to ASCENDING order (oldest first, newest last)
//        return messages.sorted { $0.date < $1.date }
//    }
    
    private func sortMessagesByDateDescending(_ messages: [Message]) -> [Message] {
        // Keep this for when you need descending order elsewhere
        return messages.sorted { $0.date > $1.date }
    }
    // Add this method to distinguish between files and links
    private func isURL(_ text: String) -> Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        // Check if the entire text is a URL
        if matches.count == 1 {
            let match = matches[0]
            return match.range.location == 0 && match.range.length == text.utf16.count
        }
        return false
    }

    // MARK: - URL Scanning Methods

    /// Send URL with scanning - shows "Scanning link..." to sender
    func sendURLWithScan(_ urlText: String, chatId: Int) {
        guard !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        guard isSignalRConnected else {
            errorMessage = "Not connected to chat server. Please check your connection."
            return
        }
        
        if joinedChats.contains(chatId) {
            sendURLWithScanImmediately(urlText, chatId: chatId)
        } else {
            addPendingMessage(urlText, for: chatId)
            joinChatRoom(chatId: chatId) { [weak self] success in
                if success {
                    self?.sendURLWithScanImmediately(urlText, chatId: chatId)
                } else {
                    self?.errorMessage = "Failed to join chat. Please try again."
                    self?.removePendingMessages(for: chatId)
                }
            }
        }
        
        moveChatToTop(chatId: chatId)
    }

    private func sendURLWithScanImmediately(_ urlText: String, chatId: Int) {
        // Create a temporary "Scanning link..." message
        let tempMessageId = -Int.random(in: 1000000...9999999)
        let scanningMessage = Message(
            id: tempMessageId,
                        displayText: "🔍 Scanning link...",
            name: getCurrentUsername(),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            isRead: false
        )
        
        print("🔗 Adding scanning message for URL: \(urlText)")
        
        // Track the temp message with the actual URL
        optimisticMessageTracking[tempMessageId] = urlText
        
        // Add scanning message to chat
        addTemporaryScanningMessage(scanningMessage, chatId: chatId)
        
        // Send URL for scanning via SignalR
        if let signalR = signalRService as? SignalRService {
            signalR.sendMessageWithScan(urlText, chatId: chatId, isFile: false)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ URL scan failed: \(error)")
                        self?.handleURLScanFailure(tempMessageId: tempMessageId, chatId: chatId, error: error, url: urlText)
                    }
                }, receiveValue: { [weak self] scanResult in
                    guard let self = self else { return }
                    
                    if let scanResult = scanResult {
                        if !scanResult.isSafe {
                            print("⚠️ URL blocked: \(scanResult.message)")
                            self.handleBlockedURL(tempMessageId: tempMessageId, chatId: chatId, url: urlText, reason: scanResult.message)
                            
                            DispatchQueue.main.async {
                                self.errorMessage = "URL blocked: \(scanResult.message)"
                            }
                        } else {
                            print("✅ URL passed scan - will be sent as clickable link")
                        }
                    } else {
                        print("ℹ️ No scan result returned - waiting for SignalR echo")
                    }
                })
                .store(in: &cancellables)
        }
    }

   
    private func handleURLScanFailure(tempMessageId: Int, chatId: Int, error: Error, url: String) {
        print("❌ URL scan failure: \(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.chats.firstIndex(where: { $0.id == chatId }) {
                var updatedChat = self.chats[index]
                var messages = updatedChat.messages
                
                if let msgIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                    messages[msgIndex] = Message(
                        id: tempMessageId,
                                    displayText: "❌ Failed to scan link: \(error.localizedDescription)\n\(url)",
                        name: self.getCurrentUsername(),
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        isRead: false
                    )
                    
                    updatedChat = Chat(
                        id: updatedChat.id,
                        name: updatedChat.name,
                        pictureUrl: updatedChat.pictureUrl,
                        type: updatedChat.type,
                        messages: messages,
                        users: updatedChat.users,
                        unreadCount: 0,
                        isOnline: updatedChat.isOnline
                    )
                    self.chats[index] = updatedChat
                    
                    if self.currentChat?.id == chatId {
                        self.currentChat = updatedChat
                    }
                    
                    self.saveChats()
                    self.notifyChatsUpdated()
                }
            }
            
            self.optimisticMessageTracking.removeValue(forKey: tempMessageId)
            self.errorMessage = "Failed to scan link: \(error.localizedDescription)"
        }
    }

   
    
}




// MARK: - Updated Message Model for Better Seen Status Handling

extension Message {
    var seenByUsers: String {
        guard let seenBy = seenBy, !seenBy.isEmpty else {
            return ""
        }
        return seenBy.joined(separator: ", ")
    }
    
    var isSeen: Bool {
        return !(seenBy?.isEmpty ?? true)
    }
}
extension ChatViewModel {

    // MARK: - Voice Message (NO scanning)

    /// Call this instead of sendMessage() when the file is a voice recording.
    /// Voice messages are always type .voice (rawValue 2) and are never scanned.
    func sendVoiceMessage(fileUrl: String, fileName: String, fileSize: Int64, chatId: Int) {
        guard !fileUrl.isEmpty else {
            errorMessage = "Voice message URL is missing."
            return
        }

        guard isSignalRConnected else {
            errorMessage = "Not connected to chat server. Please check your connection."
            return
        }

        print("🎙️ Sending voice message — scanning SKIPPED (type = .voice)")

        let ext = (fileName as NSString).pathExtension.lowercased()

        let send = { [weak self] in
            guard let self = self else { return }

            // Optimistic message shows a mic icon while the server confirms delivery
            let _ = self.addOptimisticVoiceMessage(fileName: fileName, chatId: chatId)

            self.signalRService.sendMessage(
                fileUrl,               // message text = the file URL
                chatId: chatId,
                fileUrl: fileUrl,
                fileName: fileName,
                fileSize: fileSize,
                fileExtension: ext,
                type: .voice           // rawValue 2 — server will NOT scan this
            )

            self.moveChatToTop(chatId: chatId)
        }

        if joinedChats.contains(chatId) {
            send()
        } else {
            joinChatRoom(chatId: chatId) { [weak self] success in
                if success {
                    send()
                } else {
                    self?.errorMessage = "Failed to join chat. Please try again."
                }
            }
        }
    }

    // MARK: - Optimistic Voice Bubble

    /// Adds a temporary voice-note bubble ("🎙️ Voice message") while we wait
    /// for the server echo. The real message from SignalR will replace it.
    @discardableResult
    private func addOptimisticVoiceMessage(fileName: String, chatId: Int) -> Int {
        let tempId = -Int.random(in: 1_000_000...9_999_999)
        let placeholder = Message(
            id: tempId,
                        displayText: "🎙️ Voice message",
            name: getCurrentUsername(),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            isRead: true
        )

        optimisticMessageTracking[tempId] = "🎙️ Voice message"

        if var chat = currentChat, chat.id == chatId {
            var msgs = chat.messages
            msgs.append(placeholder)
            msgs = sortMessagesByDate(msgs)
            self.currentChat = Chat(
                id: chat.id, name: chat.name, pictureUrl: chat.pictureUrl,
                type: chat.type, messages: msgs, users: chat.users,
                unreadCount: 0, isOnline: chat.isOnline
            )
        }

        if let idx = chats.firstIndex(where: { $0.id == chatId }) {
            var chat = chats[idx]
            var msgs = chat.messages
            msgs.append(placeholder)
            msgs = sortMessagesByDate(msgs)
            chats[idx] = Chat(
                id: chat.id, name: chat.name, pictureUrl: chat.pictureUrl,
                type: chat.type, messages: msgs, users: chat.users,
                unreadCount: 0, isOnline: chat.isOnline
            )
            saveChats()
        }

        return tempId
    }

    // MARK: - Helper (mirrors private method in main class)

    private func sortMessagesByDate(_ messages: [Message]) -> [Message] {
        messages.sorted { $0.date < $1.date }
    }

    private func moveChatToTop(chatId: Int) {
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            let chat = chats.remove(at: index)
            chats.insert(chat, at: 0)
            saveChats()
        }
    }
    
}
