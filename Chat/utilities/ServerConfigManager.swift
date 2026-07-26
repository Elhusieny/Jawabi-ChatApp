//
//  ServerConfigManager.swift
//  Chat
//

import Foundation

class ServerConfigManager {
    static let shared = ServerConfigManager()
    
    private let primaryServerKey = "primaryServerURL"
    private let secondaryServerKey = "secondaryServerURL"
    private let isTwoStepLoginCompleteKey = "isTwoStepLoginComplete"
    
    private init() {}
    
    /// Primary server URL (first login server)
    var primaryServerURL: String {
        get {
            return UserDefaults.standard.string(forKey: primaryServerKey) ?? "http://158.220.90.131:8444"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: primaryServerKey)
        }
    }
    
    /// Secondary server URL (from login response)
    var secondaryServerURL: String {
        get {
            return UserDefaults.standard.string(forKey: secondaryServerKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: secondaryServerKey)
            // Update the active server URL
            if !newValue.isEmpty {
                activeServerURL = newValue
            }
        }
    }
    
    /// Currently active server URL
    var activeServerURL: String {
        get {
            // If we have a secondary server URL, use it
            let secondary = secondaryServerURL
            if !secondary.isEmpty {
                return secondary
            }
            // Otherwise use primary
            return primaryServerURL
        }
        set {
            // Update Utilities baseURL
            Utilities.baseURL = newValue
            UserDefaults.standard.set(newValue, forKey: "activeServerURL")
        }
    }
    
    /// Whether two-step login is complete
    var isTwoStepLoginComplete: Bool {
        get {
            return UserDefaults.standard.bool(forKey: isTwoStepLoginCompleteKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: isTwoStepLoginCompleteKey)
        }
    }
    
    /// Reset server configuration (on logout)
    func reset() {
        secondaryServerURL = ""
        isTwoStepLoginComplete = false
        // Don't reset primary server URL - keep it for next login
    }
    
    /// Save server URLs that worked
    func saveServerURL(_ url: String, type: ServerType) {
        switch type {
        case .primary:
            primaryServerURL = url
        case .secondary:
            secondaryServerURL = url
        }
    }
    
    enum ServerType {
        case primary
        case secondary
    }
}