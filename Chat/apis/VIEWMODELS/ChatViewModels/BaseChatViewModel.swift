
import Foundation
import Combine
import UIKit

class BaseChatViewModel:ObservableObject{

    // MARK: - Published State (single source of truth)
    @Published var chats: [Chat] = []
    @Published var users: [GetAllUsersDM] = []
    @Published var currentChat: Chat?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var chatsUpdated = Date()

    // Seen / delivery tracking
    @Published var messageSeenStatus: [Int: [String]] = [:]
    @Published var messageDeliveryStatus: [Int: Bool] = [:]
    @Published var fileStatusUpdates: [Int: FileStatusUpdatedData] = [:]

    // Typing
    @Published var typingIndicators: [Int: String] = [:]
    private var typingDebounceTimer: Timer?

    // Online status
    @Published var userStatuses: [String: Bool] = [:]
    private var lastUsersFetchTime: Date?
    private let usersCacheDuration: TimeInterval = 300 // 5 minutes cache
           
    // MARK: - Internal State
    var cancellables = Set<AnyCancellable>()
    var joinedChats: Set<Int> = []
    var optimisticMessageTracking: [Int: String] = [:]
    var processedMessageIds = Set<String>()
    var currentChatId: Int?
    var pendingMessages: [String: (message: String, chatId: Int)] = [:]

    // MARK: - Services (shared across sub-ViewModels)
    let networkService = GetAllChatsService.shared
    let getAllUsersService = GetAllUsersService.shared
    let signalRService: any SignalRServiceProtocol

    // MARK: - Init
    init(signalRService: any SignalRServiceProtocol = SignalRService()) {
        self.signalRService = signalRService
    }

    // MARK: - Shared Utilities

    func getCurrentUsername() -> String {
        UserDefaults.standard.string(forKey: "currentUsername")
            ?? UserDefaults.standard.string(forKey: "userDisplayName")
            ?? UserDefaults.standard.string(forKey: "userName")
            ?? "UnknownUser"
    }

    func getCurrentUserId() -> String {
        UserDefaults.standard.string(forKey: "currentUserId")
            ?? UserDefaults.standard.string(forKey: "userId")
            ?? UserDefaults.standard.string(forKey: "currentUsername")
            ?? "unknown"
    }

    func isCurrentUser(message: Message) -> Bool {
        let current = getCurrentUsername().trimmingCharacters(in: .whitespaces).lowercased()
        let sender  = message.name.trimmingCharacters(in: .whitespaces).lowercased()
        return sender == current || sender == "you"
    }

    func isSignalRConnected()-> Bool {
        (signalRService as? SignalRService)?.connectionState == .connected
    }

    func notifyChatsUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.chatsUpdated = Date()
        }
    }

    func saveChats() {
        guard let encoded = try? JSONEncoder().encode(chats) else { return }
        UserDefaults.standard.set(encoded, forKey: "chats_\(getCurrentUsername())")
    }

    func loadSavedChats() {
        let key = "chats_\(getCurrentUsername())"
        guard
            let data   = UserDefaults.standard.data(forKey: key),
            let saved  = try? JSONDecoder().decode([Chat].self, from: data)
        else {
            chats = []
            return
        }
        chats = saved.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    // Ascending sort (oldest → newest) used throughout
    func sortMessagesByDate(_ messages: [Message]) -> [Message] {
        messages.sorted { $0.date < $1.date }
    }

    // In BaseChatViewModel.swift
    func moveChatToTop(chatId: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let index = self.chats.firstIndex(where: { $0.id == chatId }) else { return }
            let chat = self.chats.remove(at: index)
            self.chats.insert(chat, at: 0)
            self.saveChats()
            self.objectWillChange.send() // ✅ Force SwiftUI to update
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

   

    // Add this method
    private func handleTypingIndicator(_ typingStatus: TypingStatus) {
        let currentUsername = getCurrentUsername()
        
        // Ignore our own typing indicators
        guard typingStatus.userName.lowercased() != currentUsername.lowercased() else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.typingIndicators[typingStatus.chatId] = typingStatus.userName
            
            // Auto-remove after 2.5 seconds of no typing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if self?.typingIndicators[typingStatus.chatId] == typingStatus.userName {
                    self?.typingIndicators.removeValue(forKey: typingStatus.chatId)
                }
            }
        }
    }
    
    // Add this method to BaseChatViewModel class (before the closing brace)

    // MARK: - SignalR Handlers Setup

    func setupSignalRHandlers() {
        guard let signalR = signalRService as? SignalRService else {
            print("⚠️ Could not cast signalRService to SignalRService")
            return
        }
        
        // MARK: - Connection State Handler
        signalR.$connectionState
            .sink { [weak self] state in
                switch state {
                case .connected:
                    print("✅ SignalR connected - joining all chat rooms")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // This method should be implemented in SignalRConnectionManager
                        if let self = self as? SignalRConnectionManager {
                            self.autoJoinAllChats()
                        }
                    }
                case .disconnected:
                    print("❌ SignalR disconnected - will retry")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if let self = self as? SignalRConnectionManager {
                            self.connectSignalR()
                        }
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // MARK: - Received Message Handler
        signalR.$receivedMessage
            .compactMap { $0 }
            .sink { [weak self] receivedMessage in
                print("📨 RAW SignalR message received")
                // This should be handled by IncomingMessageHandler
                if let handler = self as? IncomingMessageHandler {
                    handler.processIncomingRealTimeMessage(receivedMessage)
                }
            }
            .store(in: &cancellables)
        
        // MARK: - Message History Handler
        signalR.$receivedMessageHistory
            .sink { [weak self] messages in
                print("📚 Received message history via SignalR: \(messages.count) messages")
                if let handler = self as? IncomingMessageHandler {
                    handler.handleMessageHistory(messages)
                }
            }
            .store(in: &cancellables)
        
        // MARK: - Typing Status Handler ✅ ADD THIS
        signalR.$typingStatus
            .compactMap { $0 }
            .sink { [weak self] typingStatus in
                print("⌨️ Typing indicator received from: \(typingStatus.userName)")
                self?.handleTypingIndicator(typingStatus)
            }
            .store(in: &cancellables)
        
        // MARK: - User Status Handler
        signalR.$userStatus
            .compactMap { $0 }
            .sink { [weak self] userStatus in
                print("👤 User status changed: \(userStatus.userName) is \(userStatus.isOnline ? "online" : "offline")")
                self?.handleUserStatusChange(userStatus)
            }
            .store(in: &cancellables)
        
        // MARK: - Seen Status Handler
        signalR.$seenStatus
            .compactMap { $0 }
            .sink { [weak self] seenStatus in
                if seenStatus.messageId == 0 {
                    // Batch seen - all messages in chat
                    if let handler = self as? IncomingMessageHandler {
                        handler.handleAllMessagesSeen(chatId: seenStatus.chatId, userName: seenStatus.userName)
                    }
                }
            }
            .store(in: &cancellables)
        
        // MARK: - File Status Handler
        signalR.$fileStatusUpdated
            .compactMap { $0 }
            .sink { [weak self] fileData in
                print("🔍 File status updated for message (fileData.messageId): (fileData.isSafe? Safe: Blocked")
                if let handler = self as? IncomingMessageHandler {
                    handler.handleFileStatusUpdate(fileData)
                }
            }
            .store(in: &cancellables)
        
        // MARK: - Error Message Handler
        signalR.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] errorMessage in
                print("❌ SignalR Error: \(errorMessage)")
                
                if errorMessage.contains("blocked") || errorMessage.contains("flagged") || errorMessage.contains("malicious") {
                    if let handler = self as? IncomingMessageHandler {
                        handler.handleBlockedMessage(errorMessage)
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.errorMessage = errorMessage
                    }
                }
            }
            .store(in: &cancellables)
        
        // MARK: - Private Message History Handler
        signalR.$privateMessageHistory
            .sink { [weak self] messages in
                guard !messages.isEmpty else { return }
                if let handler = self as? IncomingMessageHandler {
                    handler.handleMessageHistoryWithSeenStatus(messages)
                }
            }
            .store(in: &cancellables)
        
        // MARK: - File Scanning State Handler
        signalR.$isFileScanning
            .sink { isScanning in
                if isScanning {
                    print("🔍 File scanning in progress...")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Additional Handlers for BaseChatViewModel

    private func handleUserStatusChange(_ userStatus: UserStatus) {
        print("👤 User status changed: \(userStatus.userName) is \(userStatus.isOnline ? "online" : "offline")")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.userStatuses[userStatus.userName] = userStatus.isOnline
            
            // Update online status in chats
            if let index = self.chats.firstIndex(where: { $0.name == userStatus.userName && $0.type == 1 }) {
                let updatedChat = self.rebuild(self.chats[index], isOnline: userStatus.isOnline)
                self.chats[index] = updatedChat
                
                if self.currentChat?.id == updatedChat.id {
                    self.currentChat = updatedChat
                }
                
                self.saveChats()
                self.notifyChatsUpdated()
            }
        }
    }
    func generateMessageId(_ message: ReceivedPrivateMessage) -> String {
        "\(message.from ?? "")_\(message.text ?? "")_\(message.timeStamp ?? "")_\(message.chatId ?? 0)"
    }

    // MARK: - Pending Message Queue

    func addPendingMessage(_ message: String, for chatId: Int) {
        let key = "\(chatId)_\(Date().timeIntervalSince1970)"
        pendingMessages[key] = (message: message, chatId: chatId)
    }

    func removePendingMessages(for chatId: Int) {
        pendingMessages = pendingMessages.filter { $0.value.chatId != chatId }
    }

    func processPendingMessages(for chatId: Int, using send: (String, Int) -> Void) {
        let toSend = pendingMessages.filter { $0.value.chatId == chatId }
        for (key, pending) in toSend {
            send(pending.message, pending.chatId)
            pendingMessages.removeValue(forKey: key)
        }
    }
   
    // MARK: - Chat Builder Helper (reduces boilerplate Chat(…) copies)

    func rebuild(_ chat: Chat,
                 messages: [Message]? = nil,
                 unreadCount: Int? = nil,
                 isOnline: Bool? = nil) -> Chat {
        Chat(
            id:          chat.id,
            name:        chat.name,
            pictureUrl:  chat.pictureUrl,
            type:        chat.type,
            messages:    messages    ?? chat.messages,
            users:       chat.users,
            unreadCount: unreadCount ?? chat.unreadCount,
            isOnline:    isOnline    ?? chat.isOnline
        )
    }
    
   
        
        // MARK: - User & Chat Loading
        
        func loadAllUsers(forceRefresh: Bool = false) {
            // Try to load from cache first
            if !forceRefresh && users.isEmpty {
                let hadCachedUsers = loadUsersFromCache()
                if hadCachedUsers {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.refreshUsersInBackground()
                    }
                    return
                }
            }
            
            if !forceRefresh, !users.isEmpty, let lastFetch = lastUsersFetchTime,
               Date().timeIntervalSince(lastFetch) < usersCacheDuration {
                print("📦 Using fresh in-memory users (\(users.count) users)")
                return
            }
            
            fetchUsersFromServer()
        }
        
        private func fetchUsersFromServer() {
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
                    self?.lastUsersFetchTime = Date()
                    self?.saveUsersToCache()
                    print("✅ Loaded \(users.count) users from server")
                }
                .store(in: &cancellables)
        }
        
        private func saveUsersToCache() {
            guard !users.isEmpty else { return }
            if let encoded = try? JSONEncoder().encode(users) {
                UserDefaults.standard.set(encoded, forKey: "cached_users_\(getCurrentUsername())")
                UserDefaults.standard.set(Date(), forKey: "cached_users_time_\(getCurrentUsername())")
            }
        }
        
        private func loadUsersFromCache() -> Bool {
            let username = getCurrentUsername()
            guard let usersData = UserDefaults.standard.data(forKey: "cached_users_\(username)"),
                  let cachedUsers = try? JSONDecoder().decode([GetAllUsersDM].self, from: usersData) else {
                return false
            }
            self.users = cachedUsers
            return true
        }
        
        private func refreshUsersInBackground() {
            if let lastFetch = lastUsersFetchTime,
               Date().timeIntervalSince(lastFetch) < usersCacheDuration {
                return
            }
            fetchUsersFromServer()
        }
        
        // MARK: - Chat Operations
        
        
        
        func hasChatWithUser(userId: String) -> Bool {
            let currentUserId = getCurrentUserId()
            return chats.contains { chat in
                guard chat.type == 1 else { return false }
                let userIdsInChat = chat.users.map { $0.userId }
                return userIdsInChat.contains(currentUserId) && userIdsInChat.contains(userId)
            }
        }
        
        
        // MARK: - Helper Methods
        
        func isUserOnline(for chat: Chat) -> Bool {
            if chat.type == 1 {
                return userStatuses[chat.name] ?? chat.isOnline
            }
            return false
        }
        
        func getSeenStatus(for messageId: Int) -> [String] {
            return messageSeenStatus[messageId] ?? []
        }
        
        func isMessageDelivered(_ messageId: Int) -> Bool {
            return messageDeliveryStatus[messageId] ?? false
        }
        
        func isMessageBlocked(_ messageId: Int) -> Bool {
            guard let signalR = signalRService as? SignalRService else { return false }
            if let fileStatus = signalR.fileStatusUpdated, fileStatus.messageId == messageId {
                return !fileStatus.isSafe
            }
            return signalR.blockedMessages.contains { $0.messageId == messageId }
        }
    /// Subclasses should override this to implement actual message sending
        /// Default implementation does nothing to satisfy the protocol requirement
        func sendMessageImmediately(_ text: String, chatId: Int) {
            // Abstract method - override in MessageSendingManager
            // This empty implementation prevents the compiler error
            print("⚠️ sendMessageImmediately not implemented in \(type(of: self))")
        }
    
   
    }

