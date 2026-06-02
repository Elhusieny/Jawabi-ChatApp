// MARK: - IncomingMessageHandler.swift
// Single Responsibility: processes every real-time message that arrives via SignalR.

import Foundation
import Combine
import UIKit

class IncomingMessageHandler: MessageSendingManager {

    // MARK: - Entry Point (called by SignalRHandler)

     func processIncomingRealTimeMessage(_ receivedMessage: ReceivedPrivateMessage) {
        let messageId = generateMessageId(receivedMessage)
        
        // Deduplication
        if processedMessageIds.contains(messageId) {
            print("⏭️ SKIPPING DUPLICATE message (already processed)")
            return
        }
        
        processedMessageIds.insert(messageId)
        
        // Trim processed IDs set
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
            print("🔄 Processing OWN message echo - replacing optimistic message")
            DispatchQueue.main.async { [weak self] in
                self?.replaceOptimisticMessage(receivedMessage, chatId: effectiveChatId)
            }
        } else {
            print("🔄 Processing OTHER user's message")
            handleOtherUserMessage(receivedMessage, effectiveChatId: effectiveChatId)
        }
    }

    private func handleOtherUserMessage(_ receivedMessage: ReceivedPrivateMessage, effectiveChatId: Int) {
        let newMessage = receivedMessage.toMessage()
        
        guard effectiveChatId > 0 else {
            print("❌ Cannot process other user message - invalid chatId")
            return
        }
        
        // Check if chat exists
        if let index = chats.firstIndex(where: { $0.id == effectiveChatId }) {
            // ✅ Chat exists - add message to it
            addMessageToExistingChat(newMessage, at: index, chatId: effectiveChatId)
        } else {
            // Chat doesn't exist - fetch it from server
            print("⚠️ Received message for unknown chat \(effectiveChatId) - fetching from server")
            loadChatAndAddMessage(chatId: effectiveChatId, message: newMessage, senderName: receivedMessage.from ?? "")
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
        
    // MARK: - Own Message

    private func handleOwnMessageEcho(_ received: ReceivedPrivateMessage, chatId: Int) {
        guard !(received.isFile == true && received.isSafe == false) else {
            print("🚫 Skipping replace — blocked file")
            return
        }
        guard let text = received.text else { return }
        let realId = received.actualMessageId
        guard realId > 0 else { return }

        let realMsg = received.toMessage()
        let tempId  = optimisticMessageTracking.first(where: { $0.value == text })?.key

        updateChatMessages(chatId: chatId) { [weak self] msgs in
            guard let self else { return msgs }
            var updated = msgs
            if let tid = tempId {
                updated.removeAll { $0.id == tid }
                self.optimisticMessageTracking.removeValue(forKey: tid)
            }
            if !updated.contains(where: { $0.id == realId }) {
                updated.append(realMsg)
            }
            return self.sortMessagesByDate(updated)
        }
        messageDeliveryStatus[realId] = true
        
        // ✅ FIX: Move chat to top after own message
        moveChatToTop(chatId: chatId)
        notifyChatsUpdated()
    }

    // MARK: - Other User Message

  

    private func addIncomingMessageToExistingChat(_ message: Message, at index: Int, chatId: Int) {
        let chat = chats[index]

        // Deduplication
        let isDuplicate = chat.messages.contains {
            $0.id == message.id ||
            ($0.displayText == message.displayText &&
             $0.name == message.name &&
             abs($0.date.timeIntervalSince(message.date)) < 5)
        }
        guard !isDuplicate else {
            print("⏭️ Duplicate message in chat \(chatId) — skipped")
            return
        }

        let isCurrentlyViewing = currentChatId == chatId
        let isFromSelf         = isCurrentUser(message: message)
        
        // ✅ FIX: Calculate unread count correctly
        let newUnread = (!isFromSelf && !isCurrentlyViewing)
            ? chat.unreadCount + 1
            : chat.unreadCount

        var updated = chat.messages
        updated.append(message)
        updated = sortMessagesByDate(updated)

        // ✅ FIX: Update the chat with new messages and unread count
        chats[index] = rebuild(chat, messages: updated, unreadCount: newUnread)

        if currentChat?.id == chatId { currentChat = chats[index] }

        // ✅ FIX: Move chat to top when new message arrives
        moveChatToTop(chatId: chatId)
        saveChats()
        
        // ✅ FIX: Force UI update
        notifyChatsUpdated()

        // Auto-mark as read if currently viewing
        if isCurrentlyViewing && !isFromSelf {
            markChatAsRead(chatId: chatId)
        }
    }

    // MARK: - Fetch Unknown Chat

    private func fetchChatAndAddMessage(chatId: Int, message: Message, senderName: String) {
        networkService.getChat(chatId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure = completion {
                    self?.createTemporaryChatForMessage(chatId: chatId,
                                                       message: message,
                                                       senderName: senderName)
                }
            } receiveValue: { [weak self] chat in
                guard let self else { return }
                if let existing = self.chats.firstIndex(where: { $0.id == chatId }) {
                    self.addIncomingMessageToExistingChat(message, at: existing, chatId: chatId)
                } else {
                    var msgs = chat.messages
                    msgs.append(message)
                    msgs = self.sortMessagesByDate(msgs)
                    let newChat = self.rebuild(chat, messages: msgs, unreadCount: 1)
                    self.chats.insert(newChat, at: 0)
                    self.saveChats()
                    self.joinChatRoom(chatId: chatId)
                    self.notifyChatsUpdated() // ✅ FIX: Force UI update
                }
            }
            .store(in: &cancellables)
    }

    private func createTemporaryChatForMessage(chatId: Int, message: Message, senderName: String) {
        guard chatId > 0 else { return }
        let temp = Chat(id: chatId,
                        name: senderName,
                        pictureUrl: "/uploads/users/default.png",
                        type: 1,
                        messages: [message],
                        users: [],
                        unreadCount: 1,
                        isOnline: false)
        DispatchQueue.main.async { [weak self] in
            self?.chats.insert(temp, at: 0)
            self?.saveChats()
            self?.joinChatRoom(chatId: chatId)
            self?.notifyChatsUpdated() // ✅ FIX: Force UI update
        }
    }

    // MARK: - Message History

    func handleMessageHistory(_ messages: [ReceivedPrivateMessage]) {
        guard let first = messages.first else { return }
        let chatId  = first.id
        let objects = sortMessagesByDate(messages.map { $0.toMessage() })

        if let idx = chats.firstIndex(where: { $0.id == chatId }) {
            chats[idx] = rebuild(chats[idx], messages: objects)
            if currentChat?.id == chatId { currentChat = chats[idx] }
        } else {
            let newChat = Chat(id: chatId,
                               name: first.name,
                               pictureUrl: "/uploads/users/default.png",
                               type: 1,
                               messages: objects,
                               users: [],
                               unreadCount: 0,
                               isOnline: false)
            chats.insert(newChat, at: 0)
        }
        saveChats()
        notifyChatsUpdated() // ✅ FIX: Force UI update
    }

    func handleMessageHistoryWithSeenStatus(_ messages: [MessageWithSeenStatus]) {
        guard !messages.isEmpty else { return }
        let chatId = findChatIdForMessages(messages)
        guard chatId > 0 else { return }

        let objects = messages.map { msg -> Message in
            Message(id: msg.id,
                    displayText: msg.displayText,
                    name: msg.from,
                    timestamp: msg.timeStamp,
                    isRead: msg.isRead,
                    seenBy: msg.isRead ? [partnerUsername(for: chatId)] : [])
        }

        // Update delivery status
        let currentUser = getCurrentUsername()
        for msg in messages where msg.from.lowercased() == currentUser.lowercased() {
            messageDeliveryStatus[msg.id] = msg.isRead || isPartnerOnline(for: chatId)
        }

        if let idx = chats.firstIndex(where: { $0.id == chatId }) {
            let unread = calculateUnreadCount(messages)
            chats[idx] = rebuild(chats[idx], messages: objects, unreadCount: unread)
            if currentChat?.id == chatId { currentChat = chats[idx] }
        }
        saveChats()
        notifyChatsUpdated() // ✅ FIX: Force UI update
    }

    // MARK: - Private Helpers

    private func findChatIdForMessages(_ messages: [MessageWithSeenStatus]) -> Int {
        for msg in messages {
            if let chat = chats.first(where: { $0.name == msg.from && $0.type == 1 }) {
                return chat.id
            }
        }
        return (signalRService as? SignalRService)?.lastSentChatId ?? 0
    }

    private func calculateUnreadCount(_ messages: [MessageWithSeenStatus]) -> Int {
        let me = getCurrentUsername()
        return messages.filter { !$0.isRead && $0.from.lowercased() != me.lowercased() }.count
    }

    func partnerUsername(for chatId: Int) -> String {
        chats.first(where: { $0.id == chatId })?.name ?? ""
    }

    func isPartnerOnline(for chatId: Int) -> Bool {
        userStatuses[partnerUsername(for: chatId)] ?? false
    }
    
    // MARK: - Additional Handlers
    
     func handleAllMessagesSeen(chatId: Int, userName: String) {
        print("👁️✅ Processing: \(userName) has seen ALL messages in chat \(chatId)")
        
        let currentUsername = getCurrentUsername()
        guard userName.lowercased() != currentUsername.lowercased() else { return }
        
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else { return }
        
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
                }
            }
        }
        
        if hasChanges {
            updatedChat = rebuild(updatedChat, messages: updatedMessages)
            chats[chatIndex] = updatedChat
            if currentChat?.id == chatId { currentChat = updatedChat }
            saveChats()
            notifyChatsUpdated()
        }
    }
    
    private func handleUserStatusChange(_ userStatus: UserStatus) {
        print("👤 User status changed: \(userStatus.userName) is \(userStatus.isOnline ? "online" : "offline")")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.userStatuses[userStatus.userName] = userStatus.isOnline
            
            if userStatus.isOnline, let chatIndex = self.chats.firstIndex(where: { $0.name == userStatus.userName && $0.type == 1 }) {
                let chat = self.chats[chatIndex]
                for message in chat.messages where self.isCurrentUser(message: message) {
                    self.messageDeliveryStatus[message.id] = true
                }
            }
            
            if let index = self.chats.firstIndex(where: { $0.name == userStatus.userName && $0.type == 1 }) {
                self.chats[index] = self.rebuild(self.chats[index], isOnline: userStatus.isOnline)
                self.saveChats()
                self.notifyChatsUpdated()
            }
        }
    }
    
    func markVisibleMessagesAsSeen(chatId: Int, messageIds: [Int]) {
        print("👁️ We saw \(messageIds.count) messages in chat \(chatId)")
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
    
    private func getPartnerUsername(for chatId: Int) -> String {
        if let chat = chats.first(where: { $0.id == chatId }) {
            return chat.name
        }
        let currentUsername = getCurrentUsername()
        if let firstMessage = currentChat?.messages.first {
            return firstMessage.name == currentUsername ? "" : firstMessage.name
        }
        return ""
    }
    
    private func isMessageFromCurrentUser(_ message: MessageWithSeenStatus) -> Bool {
        let currentUsername = getCurrentUsername()
        return message.from.lowercased() == currentUsername.lowercased()
    }
    
     func handleBlockedMessage(_ errorMessage: String) {
        print("🚫 Handling blocked message: \(errorMessage)")
        self.errorMessage = errorMessage
    }
    
    // MARK: - Message Processing Methods

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
        
        // ✅ Only increment unread count if:
        // 1. Not from current user AND
        // 2. Not currently viewing the chat
        let newUnreadCount = (!isFromCurrentUser && !isCurrentlyViewing)
            ? updatedChat.unreadCount + 1
            : updatedChat.unreadCount
        
        print("💬 Adding message to chat \(chatId): unread=\(newUnreadCount), viewing=\(isCurrentlyViewing), fromSelf=\(isFromCurrentUser)")
        print("📝 Last message: \(message.displayText.prefix(50))")
        
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
        
        // ✅ CRITICAL: Move chat to top and save
        moveChatToTop(chatId: chatId)
        saveChats()
        
        // ✅ FORCE UI UPDATE
        notifyChatsUpdated()
        
        // Mark as read if currently viewing and not from self
        if isCurrentlyViewing && !isFromCurrentUser {
            markChatAsRead(chatId: chatId)
        }
    }

    

    // Add this helper to update last message preview
    private func updateLastMessagePreview(chatId: Int) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else { return }
        
        let chat = chats[index]
        let sortedMessages = chat.messages.sorted { $0.date > $1.date }
        
        if let lastMessage = sortedMessages.first {
            print("📱 Updated last message preview for chat \(chat.name): \(lastMessage.displayText.prefix(50))")
        }
    }
    
     func handleFileStatusUpdate(_ fileData: FileStatusUpdatedData) {
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
        
}
