
// KeychainManager.swift
import Foundation
import Security
import SwiftUI

class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.yourapp.chat"
    
    // Save credentials when user logs in
    func saveCredentials(username: String, password: String) {
        let account = username
        guard let passwordData = password.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Delete existing entry if any
        SecItemDelete(query as CFDictionary)
        
        // Add new entry
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("✅ Credentials saved to Keychain for: \(username)")
        } else {
            print("❌ Failed to save credentials: \(status)")
        }
    }
    
    // Get saved credentials for a specific username
    func getCredentials(for username: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    // Get all saved usernames
    func getAllSavedUsernames() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: false
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        var usernames: [String] = []
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            for item in items {
                if let username = item[kSecAttrAccount as String] as? String {
                    usernames.append(username)
                }
            }
        }
        return usernames
    }
    
    // Delete credentials for a specific username
    func deleteCredentials(for username: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            print("✅ Credentials deleted for: \(username)")
        }
    }
    
    // Clear all saved credentials (optional)
    func clearAllCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
