//
//  ChatSummary.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 04/01/2026.
//
import Foundation


/// Model matching the API response from GetChatsWithLastMessage
struct ChatSummary: Codable {
    let id: Int
    let name: String
    let pictureUrl: String
    let lastMessage: LastMessageInfo?
    let type: Int
}

struct LastMessageInfo: Codable {
    let text: String
    let time: String
}
