import Foundation
/// Model matching the API response from GetChatsWithLastMessage
struct ChatSummary: Codable {
    let id: Int
    let name: String?           // ← was String
    let pictureUrl: String?     // ← was String
    let lastMessage: LastMessageInfo?
    let unreadCount: Int?       // ← add this, you're missing it
    let isOnline: Bool?         // ← add this too
    let type: Int?              // ← harden this as well
}

struct LastMessageInfo: Codable {
    let text: String
    let time: String
}
