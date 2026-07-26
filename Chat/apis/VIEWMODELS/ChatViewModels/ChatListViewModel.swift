//
//  ChatListViewModel.swift
//  Chat
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ChatListViewModel: ObservableObject {
    
    @Published var chats: [ChatEntity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let chatStore: ChatStore
    private var cancellables = Set<AnyCancellable>()
    
    init(chatStore: ChatStore) {
        self.chatStore = chatStore
        
        // Subscribe to ChatStore updates
        chatStore.$chats
            .receive(on: DispatchQueue.main)
            .assign(to: &$chats)
    }
    
    func getTypingStatus(for chatId: Int) -> String? {
        return chatStore.getTypingStatus(for: chatId)
    }
    
    func clearUnread(chatId: Int) {
        chatStore.clearUnread(chatId: chatId)
    }
}