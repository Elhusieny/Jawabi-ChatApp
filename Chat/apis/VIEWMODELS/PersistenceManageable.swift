//
//  PersistenceManageable.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 12/05/2026.
//


// ChatPersistenceManager.swift
import Foundation

// MARK: - Persistence Protocol (Interface Segregation)
protocol PersistenceManageable {
    func saveChats(_ chats: [Chat], for username: String)
    func loadChats(for username: String) -> [Chat]
    func saveUsers(_ users: [GetAllUsersDM])
    func loadUsers() -> [GetAllUsersDM]?
    func saveCurrentUserInfo(userId: String, username: String, token: String)
    func getCurrentUserInfo() -> (userId: String?, username: String?, token: String?)
}

// MARK: - Persistence Manager Implementation
class ChatPersistenceManager: PersistenceManageable {
    
    static let shared = ChatPersistenceManager()
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Chat Persistence
    
    func saveChats(_ chats: [Chat], for username: String) {
        if let encoded = try? JSONEncoder().encode(chats) {
            userDefaults.set(encoded, forKey: "chats_\(username)")
            print("💾 Saved \(chats.count) chats to cache")
        }
    }
    
    func loadChats(for username: String) -> [Chat] {
        guard let data = userDefaults.data(forKey: "chats_\(username)"),
              let chats = try? JSONDecoder().decode([Chat].self, from: data) else {
            return []
        }
        print("💾 Loaded \(chats.count) cached chats")
        return chats.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }
    
    // MARK: - Users Persistence
    
    func saveUsers(_ users: [GetAllUsersDM]) {
        if let encoded = try? JSONEncoder().encode(users) {
            userDefaults.set(encoded, forKey: "cached_users")
            userDefaults.set(Date(), forKey: "cached_users_time")
            print("💾 Saved \(users.count) users to cache")
        }
    }
    
    func loadUsers() -> [GetAllUsersDM]? {
        guard let data = userDefaults.data(forKey: "cached_users"),
              let users = try? JSONDecoder().decode([GetAllUsersDM].self, from: data) else {
            return nil
        }
        
        // Check cache age (5 minutes)
        if let cacheTime = userDefaults.object(forKey: "cached_users_time") as? Date,
           Date().timeIntervalSince(cacheTime) < 300 {
            print("📦 Using cached users (\(users.count) users)")
            return users
        }
        
        return users // Return cached but will refresh in background
    }
    
    // MARK: - User Info Persistence
    
    func saveCurrentUserInfo(userId: String, username: String, token: String) {
        userDefaults.set(userId, forKey: "currentUserId")
        userDefaults.set(username, forKey: "currentUsername")
        userDefaults.set(token, forKey: "authToken")
        print("💾 Saved user info: \(username) (ID: \(userId))")
    }
    
    func getCurrentUserInfo() -> (userId: String?, username: String?, token: String?) {
        let userId = userDefaults.string(forKey: "currentUserId")
        let username = userDefaults.string(forKey: "currentUsername")
        let token = userDefaults.string(forKey: "authToken")
        return (userId, username, token)
    }
    
    // MARK: - Utility
    
    func clearAllCache() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix("chats_") || key == "cached_users" {
            userDefaults.removeObject(forKey: key)
        }
        print("🗑️ Cleared all chat cache")
    }
}