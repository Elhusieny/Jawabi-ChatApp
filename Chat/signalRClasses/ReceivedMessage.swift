//
//import Foundation
// //MARK: - SignalR Received Message Model
//struct ReceivedMessage: Codable {
//    // Handle both uppercase and lowercase
//    let From: String?
//    let from: String?
//    let Text: String?
//    let text: String?
//    let TimeStamp: String?
//    let timeStamp: String?
//    let ChatId: Int?
//    let chatId: Int?
//    
//    // Computed properties for easy access
//    var name: String {
//        return from ?? From ?? "Unknown"
//    }
//    
//    var messageText: String {
//        return text ?? Text ?? ""
//    }
//    
//    var id: Int {
//        return chatId ?? ChatId ?? 0
//    }
//    
//    var timestampString: String {
//        return timeStamp ?? TimeStamp ?? Date().ISO8601Format()
//    }
//    
//    // Convert to Message
//    func toMessage() -> Message {
//        // Create unique ID from hash
//        let messageId = "\(name)\(messageText)\(timestampString)".hashValue
//        
//        return Message(
//            id: abs(messageId),
//            text: messageText,
//            name: name,
//            timestamp: timestampString
//        )
//    }
//    
//    // Initialize
//    init(From: String? = nil,
//         from: String? = nil,
//         Text: String? = nil,
//         text: String? = nil,
//         TimeStamp: String? = nil,
//         timeStamp: String? = nil,
//         ChatId: Int? = nil,
//         chatId: Int? = nil) {
//        self.From = From
//        self.from = from
//        self.Text = Text
//        self.text = text
//        self.TimeStamp = TimeStamp
//        self.timeStamp = timeStamp
//        self.ChatId = ChatId
//        self.chatId = chatId
//    }
//}
//struct TypingInfo: Codable {
//    let userName: String
//    let chatId: Int
//}
