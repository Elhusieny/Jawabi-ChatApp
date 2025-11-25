//
//  ReceivedMessage.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 25/11/2025.
//


import Foundation

// SignalR Received Message Model
struct ReceivedMessage: Codable {
    let name: String
    let text: String
    let id: Int
    let timeStamp: String
    
    var date: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeStamp) ?? Date()
    }
    
    // Convert to your existing Message model
    func toMessage() -> Message {
        return Message(
            id: self.id,
            text: self.text,
            name: self.name,
            timestamp: self.timeStamp
        )
    }
}

struct TypingInfo: Codable {
    let userName: String
    let chatId: Int
}