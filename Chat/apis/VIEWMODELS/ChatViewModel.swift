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
    private let signalRService: any SignalRServiceProtocol
    private var lastSentChatId: Int?

    private var optimisticMessageTracking: [Int: String] = [:] // [tempMessageId: text]

    // Message deduplication
    private var processedMessageIds = Set<String>()
    private var lastProcessedMessageTime: Date?
    private let messageDeduplicationWindow: TimeInterval = 2.0
    @Published var chatsUpdated = Date()
    
    @Published var messageSeenStatus: [Int: [String]] = [:] // ✅ ADD THIS: messageId -> [userNames]

    @Published var messageDeliveryStatus: [Int: Bool] = [:] // ✅ ADD: messageId -> isDelivered

    
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
                            text: lastMessage,
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
    
    private func autoJoinAllChats() {
        guard isSignalRConnected else {
            print("❌ Cannot auto-join chats - SignalR not connected")
            return
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
    
    func sendMessage(_ text: String, chatId: Int) {
        let trimmedMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        guard isSignalRConnected else {
            errorMessage = "Not connected to chat server. Please check your connection."
            return
        }
        
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
        
        moveChatToTop(chatId: chatId)
    }
    
    private func sendMessageImmediately(_ text: String, chatId: Int) {
        let tempMessageId = addOptimisticMessage(text, chatId: chatId)
        moveChatToTop(chatId: chatId)
        signalRService.sendMessage(text, chatId: chatId, photoUrl: nil)
    }
    
    private func addOptimisticMessage(_ text: String, chatId: Int) -> Int {
        let tempMessageId = -Int.random(in: 1000000...9999999)
          let optimisticMessage = Message(
              id: tempMessageId,
              text: text,
              name: getCurrentUsername(),
              timestamp: ISO8601DateFormatter().string(from: Date()),
              isRead: true
          )
          
          print("📝 Adding optimistic message with ID \(tempMessageId) for text: '\(text)'")
          
          // ⚠️ CRITICAL: Track this optimistic message
          optimisticMessageTracking[tempMessageId] = text
        
        if var currentChat = currentChat, currentChat.id == chatId {
            var updatedMessages = currentChat.messages
            updatedMessages.append(optimisticMessage)
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
        guard let receivedText = receivedMessage.text else {
            print("⚠️ Cannot replace - missing text")
            return
        }

        // ✅ FIX: Use actualMessageId instead of id (which is chatId)
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
                for optimisticMsg in optimisticMessages.reversed() { // Check most recent first
                    if optimisticMsg.text == receivedText && isCurrentUser(message: optimisticMsg) {
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
                    msg.id < 0 && msg.text == receivedText && isCurrentUser(message: msg)
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
    // ✅ FIXED: Process incoming messages and immediately replace optimistic ones
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
                // ✅ CRITICAL FIX: Replace on MAIN THREAD immediately
                DispatchQueue.main.async { [weak self] in
                    self?.replaceOptimisticMessageImmediately(receivedMessage, chatId: effectiveChatId)
                }
            } else {
                print("🔄 Processing OTHER user's message")
                handleOtherUserMessage(receivedMessage, effectiveChatId: effectiveChatId)
            }
        }
        
      
    // ✅ NEW: Immediate replacement on main thread
    private func replaceOptimisticMessageImmediately(_ receivedMessage: ReceivedPrivateMessage, chatId: Int) {
        guard let receivedText = receivedMessage.text else {
            print("⚠️ Cannot replace - missing text")
            return
        }
        
        let receivedMessageId = receivedMessage.actualMessageId
        
        guard receivedMessageId > 0 else {
            print("⚠️ Cannot replace - invalid message ID: \(receivedMessageId)")
            return
        }
        
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
        
        // Update current chat IMMEDIATELY
        if var currentChat = currentChat, currentChat.id == chatId {
            var messages = currentChat.messages
            
            if let tempId = tempMessageIdToRemove {
                messages.removeAll { $0.id == tempId }
                optimisticMessageTracking.removeValue(forKey: tempId)
            }
            
            if !messages.contains(where: { $0.id == receivedMessageId }) {
                messages.append(realMessage)
                messages.sort { $0.date > $1.date }
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
        
        // Update chats list
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            var messages = updatedChat.messages
            
            if let tempId = tempMessageIdToRemove {
                messages.removeAll { $0.id == tempId }
            }
            
            if !messages.contains(where: { $0.id == receivedMessageId }) {
                messages.append(realMessage)
                messages.sort { $0.date > $1.date }
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
        }
        
        // ✅ Mark as delivered since we got confirmation from server
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
            (existingMessage.text == message.text &&
             existingMessage.name == message.name &&
             abs(existingMessage.date.timeIntervalSince(message.date)) < 5)
        }
        
        guard !isDuplicate else {
            print("⏭️ Skipping duplicate message in chat \(chatId)")
            return
        }
        
        var updatedMessages = updatedChat.messages
        updatedMessages.append(message)
        updatedMessages.sort { $0.date > $1.date }
        
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
    
    private func handleMessageHistory(_ messages: [ReceivedPrivateMessage]) {
        guard !messages.isEmpty, let firstMessage = messages.first else { return }
        
        let chatId = firstMessage.id
        let messageObjects = messages.map { $0.toMessage() }
        
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[index]
            updatedChat = Chat(
                id: updatedChat.id,
                name: updatedChat.name,
                pictureUrl: updatedChat.pictureUrl,
                type: updatedChat.type,
                messages: messageObjects,
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
                messages: messageObjects,
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
                    self?.errorMessage = "Failed to load chat: \(error.localizedDescription)"
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
    
    private func saveChats() {
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
    
    // Updated sendImageMessage method for ChatViewModel
        func sendImageMessage(_ image: UIImage, chatId: Int) {
            isLoading = true
            
            ImageUploadService.shared.uploadImage(image) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    switch result {
                    case .success(let response):
                        print("✅ Image uploaded successfully")
                        print("   File: \(response.fileName)")
                        print("   URL: \(response.url)")
                        
                        // Send the full URL as the message
                        let fullImageUrl = response.url
                        
                        // Send message via SignalR
                        self?.signalRService.sendMessage(
                            fullImageUrl,  // Send URL as message text
                            chatId: chatId,
                            photoUrl: fullImageUrl  // Also pass as photoUrl parameter
                        )
                        
                    case .failure(let error):
                        print("❌ Image upload failed: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to upload image: \(error.localizedDescription)"
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
    
    // MARK: - Private Helpers
    
    private func moveChatToTop(chatId: Int) {
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            let chat = chats.remove(at: index)
            chats.insert(chat, at: 0)
            saveChats()
        }
    }
    
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
    private func notifyChatsUpdated() {
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
                                text: message.text,
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
                            text: message.text,
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
    }

extension ReceivedPrivateMessage {
    var debugDescription: String {
        return "Message(id: \(id ?? -1), from: \(from ?? "nil"), text: \(text?.prefix(20) ?? "nil")..., chatId: \(chatId ?? 0), time: \(timeStamp ?? "nil"))"
    }
}
