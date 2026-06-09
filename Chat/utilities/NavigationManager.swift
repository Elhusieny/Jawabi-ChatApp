//
//  NavigationManager.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 07/06/2026.
//


import SwiftUI

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var navigationPath = NavigationPath()
    @Published var pendingChatId: Int?
    @Published var shouldNavigateToChat = false
    
    func navigateToChat(chatId: Int) {
        print("📍 NavigationManager: Navigating to chat \(chatId)")
        pendingChatId = chatId
        shouldNavigateToChat = true
        navigationPath.append(chatId)
    }
    
    func clearPendingNavigation() {
        pendingChatId = nil
        shouldNavigateToChat = false
    }
}