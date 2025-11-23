import Combine
import Foundation

class ChatViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var users: [APIUser] = []
    @Published var currentChat: Chat?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let networkService = NetworkService.shared
    
    // Generate a unique key for each user's chats
    private var chatsKey: String {
        if let currentUser = getCurrentUsername() {
            return "chats_\(currentUser)"
        }
        return "chats_anonymous"
    }
    private var refreshTimer: Timer?
     private var currentChatId: Int?
     
    
    init() {
        loadSavedChats()
    }
    
     func startPollingForChat(chatId: Int) {
         currentChatId = chatId
         stopPolling()
         
         // Refresh every 2 seconds
         refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
             self?.refreshChat(chatId: chatId)
         }
     }
     
     func stopPolling() {
         refreshTimer?.invalidate()
         refreshTimer = nil
     
     
 }
    
    // MARK: - Get current username for storage key
    private func getCurrentUsername() -> String? {
        return UserDefaults.standard.string(forKey: "currentUsername")
    }
    
    // MARK: - Local Storage
    private func saveChats() {
        if let encoded = try? JSONEncoder().encode(chats) {
            UserDefaults.standard.set(encoded, forKey: chatsKey)
            print("💾 Saved \(chats.count) chats for user: \(getCurrentUsername() ?? "unknown")")
        }
    }
    
    private func loadSavedChats() {
        if let savedChatsData = UserDefaults.standard.data(forKey: chatsKey),
           let savedChats = try? JSONDecoder().decode([Chat].self, from: savedChatsData) {
            self.chats = savedChats.sorted { $0.lastMessageDate > $1.lastMessageDate }
            print("📂 Loaded \(savedChats.count) saved chats for user: \(getCurrentUsername() ?? "unknown")")
        } else {
            print("📂 No saved chats found for user: \(getCurrentUsername() ?? "unknown")")
            self.chats = []
        }
    }
    
    // MARK: - Clear chats when user logs out
    func clearUserChats() {
        chats.removeAll()
        // Don't save when clearing - we want to keep them for the current user
        print("🧹 Cleared chats from memory for user: \(getCurrentUsername() ?? "unknown")")
    }
    
    // MARK: - Create Private Chat (with duplicate check and local storage)
    func createPrivateChat(with userId: String) {
        // First check if we already have a chat with this user
        if let existingChat = findChatWithUser(userId: userId) {
            print("✅ Chat already exists with user, opening: \(existingChat.name) (ID: \(existingChat.id))")
            currentChat = existingChat
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("🎯 Creating new chat with user ID: \(userId)")
        
        networkService.createPrivateChat(with: userId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    let errorMessage = "Failed to create chat: \(error.localizedDescription)"
                    self?.errorMessage = errorMessage
                    print("❌ Error creating chat: \(errorMessage)")
                case .finished:
                    print("✅ Chat creation completed")
                }
            } receiveValue: { [weak self] response in
                print("✅ New chat created: \(response.chatData.name) (ID: \(response.chatData.id))")
                
                // Add the new chat to the beginning and save locally
                self?.chats.insert(response.chatData, at: 0)
                self?.currentChat = response.chatData
                self?.saveChats()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper method to find existing chat with user
    private func findChatWithUser(userId: String) -> Chat? {
        return chats.first { chat in
            // Check if any user in the chat matches the target user ID
            chat.users.contains { $0.userId == userId }
        }
    }
    
    // MARK: - Check if user already has a chat
    func hasChatWithUser(userId: String) -> Bool {
        return findChatWithUser(userId: userId) != nil
    }
    
    // MARK: - Load All Users (for new chat)
    func loadAllUsers() {
        isLoading = true
        errorMessage = nil
        
        print("👥 Loading all users...")
        
        networkService.getAllUsers()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    self?.errorMessage = "Failed to load users: \(error.localizedDescription)"
                    print("❌ Error loading users: \(error)")
                case .finished:
                    print("✅ Users loaded successfully")
                }
            } receiveValue: { [weak self] users in
                self?.users = users
                print("✅ Loaded \(users.count) users: \(users.map { $0.name })")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Send Message
    func sendMessage(_ text: String, chatId: Int) {
        let request = SendMessageRequest(Message: text, chatId: chatId)
        
        print("📤 Sending message to chat \(chatId): \(text)")
        
        networkService.sendMessage(request)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    self?.errorMessage = "Failed to send message: \(error.localizedDescription)"
                    print("❌ Error sending message: \(error)")
                case .finished:
                    print("✅ Message sent successfully")
                    // Move chat to top after sending message
                    self?.moveChatToTop(chatId: chatId)
                }
            } receiveValue: { [weak self] _ in
                // Refresh the chat to get latest messages
                self?.refreshChat(chatId: chatId)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper method to move chat to top
    private func moveChatToTop(chatId: Int) {
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChats = chats
            let chat = updatedChats.remove(at: index)
            updatedChats.insert(chat, at: 0)
            chats = updatedChats
            saveChats()
        }
    }
    
    // MARK: - Refresh Chat (updated to also save locally)
    // Update refreshChat to handle real-time updates
    func refreshChat(chatId: Int) {
        networkService.getChat(chatId)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("❌ Error refreshing chat: \(error)")
                }
            } receiveValue: { [weak self] chat in
                print("🔄 Chat refreshed with \(chat.messages.count) messages")
                
                // Update current chat
                self?.currentChat = chat
                
                // Update the chat in the main chats list
                if let index = self?.chats.firstIndex(where: { $0.id == chat.id }) {
                    self?.chats[index] = chat
                    self?.saveChats()
                }
            }
            .store(in: &cancellables)
    }
    // MARK: - Load Specific Chat
    func loadChat(chatId: Int) {
        isLoading = true
        errorMessage = nil
        
        print("📋 Loading chat \(chatId)")
        
        networkService.getChat(chatId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    self?.errorMessage = "Failed to load chat: \(error.localizedDescription)"
                    print("❌ Error loading chat: \(error)")
                case .finished:
                    print("✅ Chat load completed")
                }
            } receiveValue: { [weak self] chat in
                print("✅ Chat loaded: \(chat.name) with \(chat.messages.count) messages")
                self?.currentChat = chat
                
                // Update the chat in local storage if it exists
                if let index = self?.chats.firstIndex(where: { $0.id == chat.id }) {
                    self?.chats[index] = chat
                    self?.saveChats()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Delete Chat
    func deleteChat(_ chatId: Int) {
        chats.removeAll { $0.id == chatId }
        saveChats()
        print("🗑️ Deleted chat with ID: \(chatId)")
    }
}
extension Chat {
    var lastMessageDate: Date {
        if let lastMessage = messages.last {
            return lastMessage.date
        }
        return Date() // Return current date if no messages
    }
}

