////
////  ChatService.swift
////  Chat
////
////  Created by Ahmed Elhussieny on 12/05/2026.
////
//
//
//// Services/ChatService.swift
//import Foundation
//import Combine
//
//class ChatService {
//    private let networkService = GetAllChatsService.shared
//    private let getAllUsersService = GetAllUsersService.shared
//    
//    func fetchAllChats() -> AnyPublisher<[Chat], Error> {
//        return networkService.getAllChats()
//            .map { chats in
//                chats.map { $0.toChat() }
//            }
//            .eraseToAnyPublisher()
//    }
//    
//    func fetchChat(chatId: Int) -> AnyPublisher<Chat, Error> {
//        return networkService.getChat(chatId)
//    }
//    
//    func createPrivateChat(with userId: String) -> AnyPublisher<ChatResponse, Error> {
//        return PrivateChatService.shared.createPrivateChat(with: userId)
//    }
//    
//    func fetchAllUsers() -> AnyPublisher<[GetAllUsersDM], Error> {
//        return getAllUsersService.getAllUsers()
//    }
//}
