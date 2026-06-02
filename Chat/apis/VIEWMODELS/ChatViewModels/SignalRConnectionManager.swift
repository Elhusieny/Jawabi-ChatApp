


// MARK: - SignalRConnectionManager.swift
// Single Responsibility: owns SignalR connect / disconnect / room-join logic.

import Foundation
import Combine

class SignalRConnectionManager:BaseChatViewModel {

    // MARK: - Public API

    /// Connects SignalR if an auth token exists.
    func connectSignalR() {
        guard UserDefaults.standard.string(forKey: "authToken") != nil else {
            print("❌ Cannot connect SignalR — no auth token")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.signalRService.connect()
        }
    }

    func disconnectSignalR() {
        signalRService.disconnect()
    }
    /// Load a specific chat from server by ID
       func loadChat(chatId: Int) {
           isLoading = true
           
           networkService.getChat(chatId)
               .receive(on: DispatchQueue.main)
               .sink { [weak self] completion in
                   self?.isLoading = false
                   if case .failure(let error) = completion {
                       print("❌ Failed to load chat: \(error)")
                       self?.errorMessage = error.localizedDescription
                   }
               } receiveValue: { [weak self] chat in
                   self?.currentChat = chat
                   
                   // Update in chats array if exists
                   if let index = self?.chats.firstIndex(where: { $0.id == chat.id }) {
                       self?.chats[index] = chat
                       self?.saveChats()
                   }
                   
                   self?.markChatAsRead(chatId: chatId)
                   self?.isLoading = false
               }
               .store(in: &cancellables)
       }
    func createPrivateChat(with userId: String) {
        isLoading = true
        errorMessage = nil
        
        PrivateChatService.shared.createPrivateChat(with: userId)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to create chat: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] response in
                self?.chats.removeAll { $0.id == response.chatData.id }
                self?.chats.insert(response.chatData, at: 0)
                self?.currentChat = response.chatData
                self?.saveChats()
                self?.joinChatRoom(chatId: response.chatData.id)
            })
            .store(in: &cancellables)
    }
    
    /// Joins a single chat room; calls completion with success flag.
    func joinChatRoom(chatId: Int, completion: ((Bool) -> Void)? = nil) {
        guard isSignalRConnected() else {
            print("❌ Cannot join chat \(chatId) — SignalR not connected")
            completion?(false)
            return
        }

        if joinedChats.contains(chatId) {
            print("ℹ️ Already joined chat \(chatId)")
            if currentChatId == chatId { markChatAsRead(chatId: chatId) }
            completion?(true)
            return
        }

        print("🚪 Joining chat room \(chatId)…")

        signalRService.joinChat(chatId: chatId) { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                if success {
                    self.joinedChats.insert(chatId)
                    print("✅ Joined chat \(chatId)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        (self.signalRService as? SignalRService)?.getMessages(chatId: chatId)
                    }
                    self.processPendingMessages(for: chatId) { [weak self] msg, cid in
                        self?.sendMessageImmediately(msg, chatId: cid)
                    }
                } else {
                    print("❌ Failed to join chat \(chatId)")
                }
                completion?(success)
            }
        }
    }

    func leaveChatRoom(chatId: Int) {
        signalRService.leaveChat(chatId: chatId)
        joinedChats.remove(chatId)
        if currentChatId == chatId { currentChatId = nil }
        typingIndicators.removeValue(forKey: chatId)
        print("🚪 Left chat \(chatId)")
    }

    /// Joins every chat in the current list (called after connection is established).
    func autoJoinAllChats() {
        guard isSignalRConnected() else {
            print("❌ Cannot auto-join — SignalR not connected")
            return
        }
        print("🔄 Auto-joining \(chats.count) chats…")
        chats.forEach { chat in
            guard !joinedChats.contains(chat.id) else { return }
            joinChatRoom(chatId: chat.id) { success in
                print(success ? "✅ Auto-joined \(chat.name)" : "❌ Failed to auto-join \(chat.name)")
            }
        }
    }

    func markChatAsRead(chatId: Int) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }),
              chats[index].unreadCount > 0
        else { return }

        chats[index] = rebuild(chats[index], unreadCount: 0)

        if currentChat?.id == chatId { currentChat = chats[index] }
        saveChats()

        (signalRService as? SignalRService)?.markAsRead(chatId: chatId)
    }

    func ensureSignalRConnection() {
        guard !isSignalRConnected() else { return }
        connectSignalR()
    }
    // MARK: - Leave Chat/Group
    func leaveChat(chatId: Int, completion: ((Bool) -> Void)? = nil) {
        guard let signalR = signalRService as? SignalRService else {
            print("❌ Cannot leave chat - SignalR not available")
            completion?(false)
            return
        }
        
        // Use the completion version
        signalR.leaveChat(chatId: chatId) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                // Remove from local storage
                if let index = self.chats.firstIndex(where: { $0.id == chatId }) {
                    self.chats.remove(at: index)
                    self.saveChats()
                    self.notifyChatsUpdated()
                    
                    // Post notification for any other views
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ChatLeft"),
                        object: nil,
                        userInfo: ["chatId": chatId]
                    )
                    
                    print("✅ Successfully left chat \(chatId)")
                    completion?(true)
                } else {
                    print("⚠️ Chat \(chatId) not found in local storage")
                    completion?(true) // Still successful on server
                }
                
                // Also remove from joined chats set
                self.joinedChats.remove(chatId)
                if self.currentChatId == chatId { self.currentChatId = nil }
            } else {
                print("❌ Failed to leave chat: \(error?.localizedDescription ?? "Unknown error")")
                self.errorMessage = "Failed to leave chat: \(error?.localizedDescription ?? "Unknown error")"
                completion?(false)
            }
        }
    }


   
}
