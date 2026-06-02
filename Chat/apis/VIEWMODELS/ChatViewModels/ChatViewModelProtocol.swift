
// MARK: - ChatViewModelProtocol.swift
// Defines the full public surface of ChatViewModel.
// Views depend on this protocol — not the concrete class — enabling
// easy mocking for SwiftUI previews and unit tests (Interface Segregation).

import Foundation
import Combine
import UIKit

protocol ChatViewModelProtocol: ObservableObject {

    // MARK: Published
    var chats: [Chat] { get }
    var currentChat: Chat? { get set }
    var isLoading: Bool { get }
    var errorMessage: String? { get set }
    var typingIndicators: [Int: String] { get }
    var userStatuses: [String: Bool] { get }
    var messageSeenStatus: [Int: [String]] { get }
    var messageDeliveryStatus: [Int: Bool] { get }
    var chatsUpdated: Date { get }

    // MARK: Connection
    func connectSignalR()

    // MARK: Chat Lifecycle
    func fetchAllChatsFromServer()
    func refreshChats()
    func loadSavedChats()
    func loadChat(chatId: Int)  // ADD THIS

    // MARK: Room Management
    func joinChatRoom(chatId: Int, completion: ((Bool) -> Void)?)
    func leaveChatRoom(chatId: Int)
    func markChatAsRead(chatId: Int)

    // MARK: Messaging
    func sendMessage(_ text: String, chatId: Int)
    func sendVoiceMessage(fileUrl: String, fileName: String, fileSize: Int64, chatId: Int)
    func sendImageMessage(_ image: UIImage, chatId: Int)
    func sendMessageImmediately(_ text: String, chatId: Int)

    // MARK: Users
    func loadAllUsers(forceRefresh: Bool)
    func createPrivateChat(with userId: String)
    func hasChatWithUser(userId: String) -> Bool

    // MARK: Typing
    func sendTypingIndicator(for chatId: Int)
    func getTypingStatus(for chatId: Int) -> String?

    // MARK: Helpers
    func isCurrentUser(message: Message) -> Bool
    func isUserOnline(for chat: Chat) -> Bool
    func getCurrentUsername() -> String
    func getCurrentUserId() -> String
    func getSeenStatus(for messageId: Int) -> [String]
    func isMessageDelivered(_ messageId: Int) -> Bool
    func isMessageBlocked(_ messageId: Int) -> Bool
    
}
