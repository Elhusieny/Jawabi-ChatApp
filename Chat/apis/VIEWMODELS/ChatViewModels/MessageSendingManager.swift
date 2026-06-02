//
//  MessageSendingManager.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 12/05/2026.
//


// MARK: - MessageSendingManager.swift
// Single Responsibility: all outgoing-message logic (text, image, voice, file, URL).
// Uses the Template Method pattern: sendMessage() decides the path;
// specialised private methods handle each case.

import Foundation
import Combine
import UIKit

class MessageSendingManager: SignalRConnectionManager {

    // MARK: - Timers
    private var typingDebounceTimer: Timer?

    deinit { typingDebounceTimer?.invalidate() }

    // MARK: - Public Send API
    
       override func sendMessageImmediately(_ text: String, chatId: Int) {
           let _ = addOptimisticMessage(text, chatId: chatId)
           moveChatToTop(chatId: chatId)
           
           signalRService.sendMessage(
               text,
               chatId: chatId,
               fileUrl: nil,
               fileName: nil,
               fileSize: 0,
               fileExtension: nil,
               type: .text
           )
       }

    func sendMessage(_ text: String, chatId: Int) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isSignalRConnected() else {
            errorMessage = "Not connected to chat server. Please check your connection."
            return
        }
        
        // Get chat type to determine if group or private
        let isGroup = chats.first(where: { $0.id == chatId })?.type == 0  // type 0 = group, 1 = private
        
        let dispatch: () -> Void = { [weak self] in
            guard let self else { return }
            
            // Add optimistic message locally
            let _ = self.addOptimisticMessage(trimmed, chatId: chatId)
            
            // Route to appropriate send method
            if isGroup {
                (self.signalRService as? SignalRService)?.sendGroupMessage(
                    trimmed,
                    chatId: chatId,
                    fileUrl: nil,
                    fileName: nil,
                    fileSize: nil,
                    fileExtension: nil,
                    type: .text
                )
            } else {
                self.signalRService.sendMessage(
                    trimmed,
                    chatId: chatId,
                    fileUrl: nil,
                    fileName: nil,
                    fileSize: 0,
                    fileExtension: nil,
                    type: .text
                )
            }
        }
        
        if joinedChats.contains(chatId) {
            dispatch()
        } else {
            addPendingMessage(trimmed, for: chatId)
            joinChatRoom(chatId: chatId) { [weak self] success in
                if !success {
                    self?.errorMessage = "Failed to join chat. Please try again."
                    self?.removePendingMessages(for: chatId)
                }
            }
        }
        moveChatToTop(chatId: chatId)
    }
    // MARK: - Voice Messages (never scanned)

    func sendVoiceMessage(fileUrl: String, fileName: String, fileSize: Int64, chatId: Int) {
        guard !fileUrl.isEmpty, isSignalRConnected() else {
            errorMessage = fileUrl.isEmpty
                ? "Voice message URL is missing."
                : "Not connected to chat server."
            return
        }
        
        let isGroup = chats.first(where: { $0.id == chatId })?.type == 0
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        let send: () -> Void = { [weak self] in
            guard let self else { return }
            let _ = self.addOptimisticVoiceMessage(fileName: fileName, chatId: chatId)
            
            if isGroup {
                (self.signalRService as? SignalRService)?.sendGroupMessage(
                    fileUrl,
                    chatId: chatId,
                    fileUrl: fileUrl,
                    fileName: fileName,
                    fileSize: fileSize,
                    fileExtension: ext,
                    type: .voice
                )
            } else {
                self.signalRService.sendMessage(
                    fileUrl,
                    chatId: chatId,
                    fileUrl: fileUrl,
                    fileName: fileName,
                    fileSize: fileSize,
                    fileExtension: ext,
                    type: .voice
                )
            }
            self.moveChatToTop(chatId: chatId)
        }
        
        if joinedChats.contains(chatId) {
            send()
        } else {
            joinChatRoom(chatId: chatId) { [weak self] success in
                if success { send() }
                else { self?.errorMessage = "Failed to join chat. Please try again." }
            }
        }
    }

    // MARK: - Image Messages
    func sendImageMessage(_ image: UIImage, chatId: Int) {
        let isGroup = chats.first(where: { $0.id == chatId })?.type == 0
        
        isLoading = true
        let tempId = addUploadingPlaceholder("📤 Uploading image…", chatId: chatId)
        
        ImageUploadService.shared.uploadImage(image) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.removeOptimisticMessage(tempId, chatId: chatId)
                    let fileName = (response.url as NSString).lastPathComponent
                    let ext = (fileName as NSString).pathExtension.lowercased()
                    let fileSize = Int64(image.jpegData(compressionQuality: 0.8)?.count ?? 0)
                    
                    if isGroup {
                        (self.signalRService as? SignalRService)?.sendGroupMessage(
                            response.url,
                            chatId: chatId,
                            fileUrl: response.url,
                            fileName: fileName,
                            fileSize: fileSize,
                            fileExtension: ext,
                            type: .image
                        )
                    } else {
                        self.signalRService.sendMessage(
                            response.url,
                            chatId: chatId,
                            fileUrl: response.url,
                            fileName: fileName,
                            fileSize: fileSize,
                            fileExtension: ext,
                            type: .image
                        )
                    }
                case .failure(let error):
                    self.updateOptimisticMessageText(tempId, newText: "❌ Failed to upload image", chatId: chatId)
                    self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                }
            }
        }
    }
    // MARK: - Typing Indicator

//    func sendTypingIndicator(for chatId: Int) {
//        typingDebounceTimer?.invalidate()
//        typingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
//            (self?.signalRService as? SignalRService)?.sendTypingIndicator(chatId: chatId)
//        }
//    }
//
//    func getTypingStatus(for chatId: Int) -> String? {
//        typingIndicators[chatId]
//    }

    // MARK: - Optimistic Message Helpers

    @discardableResult
    func addOptimisticMessage(_ text: String, chatId: Int) -> Int {
        let tempId = -Int.random(in: 1_000_000...9_999_999)
        let msg = Message(
            id: tempId,
            displayText: text,
            name: getCurrentUsername(),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            isRead: true
        )
        optimisticMessageTracking[tempId] = text
        insertMessageIntoChat(msg, chatId: chatId, unreadCount: 0)
        return tempId
    }

    @discardableResult
    func addOptimisticVoiceMessage(fileName: String, chatId: Int) -> Int {
        let tempId = -Int.random(in: 1_000_000...9_999_999)
        let msg = Message(
            id: tempId,
            displayText: "🎙️ Voice message",
            name: getCurrentUsername(),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            isRead: true
        )
        optimisticMessageTracking[tempId] = "🎙️ Voice message"
        insertMessageIntoChat(msg, chatId: chatId, unreadCount: 0)
        return tempId
    }

    @discardableResult
    private func addUploadingPlaceholder(_ text: String, chatId: Int) -> Int {
        let tempId = -Int.random(in: 1_000_000...9_999_999)
        let msg = Message(
            id: tempId,
            displayText: text,
            name: getCurrentUsername(),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            isRead: false
        )
        insertMessageIntoChat(msg, chatId: chatId, unreadCount: 0)
        return tempId
    }

    func removeOptimisticMessage(_ tempId: Int, chatId: Int) {
        optimisticMessageTracking.removeValue(forKey: tempId)
        removeMessageFromChat(id: tempId, chatId: chatId)
    }

    func removeRecentOptimisticMessage() {
        guard let lastId = optimisticMessageTracking.keys.max() else { return }
        optimisticMessageTracking.removeValue(forKey: lastId)
        for (chatIndex, chat) in chats.enumerated() {
            var msgs = chat.messages
            let before = msgs.count
            msgs.removeAll { $0.id == lastId }
            guard msgs.count < before else { continue }
            chats[chatIndex] = rebuild(chat, messages: msgs)
            if currentChat?.id == chat.id { currentChat = chats[chatIndex] }
        }
        saveChats()
        notifyChatsUpdated()
    }
    
    // Add this to MessageSendingManager.swift

    // MARK: - File Scanning Methods

    func sendMessageWithScan(_ text: String, chatId: Int, isFile: Bool = false) {
        let trimmedMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        guard isSignalRConnected() else {
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

  
    func replaceOptimisticMessage(_ received: ReceivedPrivateMessage, chatId: Int) {
        // Safety: never replace with a blocked file
        guard !(received.isFile == true && received.isSafe == false) else { return }
        guard let text = received.text else { return }
        let realId = received.actualMessageId
        guard realId > 0 else { return }

        let realMsg = received.toMessage()
        var tempId: Int? = optimisticMessageTracking.first(where: { $0.value == text })?.key

        updateChatMessages(chatId: chatId) { [weak self] msgs in
            guard let self else { return msgs }
            var updated = msgs
            if let tid = tempId {
                updated.removeAll { $0.id == tid }
                self.optimisticMessageTracking.removeValue(forKey: tid)
            } else {
                // Fallback: remove any negative-id message with matching text from current user
                updated.removeAll { $0.id < 0 && $0.displayText == text && self.isCurrentUser(message: $0) }
            }
            if !updated.contains(where: { $0.id == realId }) {
                updated.append(realMsg)
            }
            return self.sortMessagesByDate(updated)
        }
        messageDeliveryStatus[realId] = true
        notifyChatsUpdated()
    }

    // MARK: - Private Utilities

    private func updateOptimisticMessageText(_ tempId: Int, newText: String, chatId: Int) {
        optimisticMessageTracking[tempId] = newText
        updateChatMessages(chatId: chatId) { msgs in
            msgs.map { msg in
                guard msg.id == tempId else { return msg }
                return Message(id: tempId,
                               displayText: newText,
                               name: msg.name,
                               timestamp: msg.timestamp,
                               isRead: false)
            }
        }
    }

    // Inserts a message into both currentChat and the chats list
    func insertMessageIntoChat(_ message: Message, chatId: Int, unreadCount: Int) {
        if var chat = currentChat, chat.id == chatId {
            var msgs = chat.messages
            msgs.append(message)
            currentChat = rebuild(chat, messages: sortMessagesByDate(msgs), unreadCount: unreadCount)
        }
        updateChatMessages(chatId: chatId) { [weak self] msgs in
            guard let self else { return msgs }
            var updated = msgs
            updated.append(message)
            return self.sortMessagesByDate(updated)
        }
    }

    private func removeMessageFromChat(id: Int, chatId: Int) {
        if var chat = currentChat, chat.id == chatId {
            currentChat = rebuild(chat, messages: chat.messages.filter { $0.id != id })
        }
        updateChatMessages(chatId: chatId) { msgs in msgs.filter { $0.id != id } }
    }

    /// Generic helper to mutate a specific chat's message array in `chats[]`.
    func updateChatMessages(chatId: Int, transform: ([Message]) -> [Message]) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else { return }
        let updated = transform(chats[index].messages)
        chats[index] = rebuild(chats[index], messages: updated)
        if currentChat?.id == chatId { currentChat = chats[index] }
        saveChats()
    }
    
   
        
        // MARK: - URL Detection Helpers
        
        private func containsURL(_ text: String) -> Bool {
            let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            return !matches.isEmpty
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
        // MARK: - Refresh Chats
        
        func refreshChats() {
            fetchAllChatsFromServer()
        }
    }
