import Foundation

// MARK: - Authentication Response Models
struct LoginResponse: Codable {
    let token: String?
    let userName: String?
    let email: String?
    let displayName: String?
    let serverUrl: String?
    
    // Handle different response structures
    enum CodingKeys: String, CodingKey {
        case token
        case userName
        case email
        case displayName
        case serverUrl = "server_url"
    }
    
    // Flexible initializer for different response formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        token = try container.decodeIfPresent(String.self, forKey: .token)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        serverUrl = try container.decodeIfPresent(String.self, forKey: .serverUrl)
    }
}

// MARK: - API User Model (for GetAllUsers)
struct GetAllUsersDM: Codable, Identifiable {
    let id: String
    let name: String
    let pictureUrl: String
    let phoneNumber: String
    
    var fullPictureUrl: String {
        print("🖼️ Building URL for \(name): original='\(pictureUrl)'")
        
        // If empty or contains default.png, return empty
        if pictureUrl.isEmpty || pictureUrl.contains("default.png") {
            print("   ➡️ Returning empty string (default image)")
            return ""
        }
        
        // If it's already a full URL, return as is
        if pictureUrl.hasPrefix("http://") || pictureUrl.hasPrefix("https://") {
            print("   ➡️ Already full URL: \(pictureUrl)")
            return pictureUrl
        }
        
        // If it starts with /uploads
        if pictureUrl.hasPrefix("/uploads") {
            let fullUrl = "http://158.220.90.131:8444" + pictureUrl
            print("   ➡️ Built URL: \(fullUrl)")
            return fullUrl
        }
        
        // Otherwise, assume it's a relative path
        let fullUrl = "http://158.220.90.131:8444/uploads/users/\(pictureUrl)"
        print("   ➡️ Built URL from relative: \(fullUrl)")
        return fullUrl
    }
}

// MARK: - App User Model (for registration/login)
struct UserRegesterationDM: Codable, Identifiable {
    let id: String
    let userName: String
    let email: String
    let displayName: String
    let phoneNumber: String
    let profilePicture: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case userName, email, displayName, phoneNumber, profilePicture
    }
}

// MARK: - Response Wrappers
struct UsersResponse: Codable {
    let result: [GetAllUsersDM]
}

// MARK: - Authentication Models
struct LoginRequest: Codable {
    let userName: String
    let password: String
    let rememberMe: Bool
    
    init(userName: String, password: String, rememberMe: Bool = true) {
        self.userName = userName
        self.password = password
        self.rememberMe = rememberMe
    }
}

struct RegisterRequest {
    let userName: String
    let email: String
    let displayName: String
    let phoneNumber: String
    let password: String
    let profilePicture: Data?
    let serverUrl:String?
}

// MARK: - Chat Model with Unread Count & Online Status
struct Chat: Codable, Identifiable {
    let id: Int
    let name: String
    let pictureUrl: String
    let type: Int
    let messages: [Message]
    let users: [ChatUser]
    var unreadCount: Int // Add unread counter
    var isOnline: Bool // Add online status
    
    var fullPictureUrl: String {
        if pictureUrl.hasPrefix("http") {
            return pictureUrl
        } else {
            return "http://158.220.90.131:8444\(pictureUrl)"
        }
    }
    
    // Custom initializer to handle optional unread/online from API
    init(id: Int, name: String, pictureUrl: String, type: Int,
         messages: [Message], users: [ChatUser],
         unreadCount: Int = 0, isOnline: Bool = false) {
        self.id = id
        self.name = name
        self.pictureUrl = pictureUrl
        self.type = type
        self.messages = messages
        self.users = users
        self.unreadCount = unreadCount
        self.isOnline = isOnline
    }
    
    // Custom decoder to handle API response
    enum CodingKeys: String, CodingKey {
        case id, name, pictureUrl, type, messages, users, unreadCount, isOnline
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        pictureUrl = try container.decode(String.self, forKey: .pictureUrl)
        type = try container.decode(Int.self, forKey: .type)
        messages = try container.decodeIfPresent([Message].self, forKey: .messages) ?? []
        users = try container.decodeIfPresent([ChatUser].self, forKey: .users) ?? []
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline) ?? false
    }
}

// MARK: - 1. Add SeenStatus Model to Models file

struct SeenStatus {
    let chatId: Int
    let messageId: Int
    let userName: String
    let timestamp: Date
}

// MARK: - 2. Update Message Model to include seen status
struct Message: Codable, Identifiable {
    let id: Int
    let text: String
    let name: String
    let timestamp: String
    var isRead: Bool?
    var seenBy: [String]? // NEW: Track who has seen the message
    
    var date: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) {
            return date
        }
        
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return fallbackFormatter.date(from: timestamp) ?? Date()
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    init(id: Int, text: String, name: String, timestamp: String, isRead: Bool? = nil, seenBy: [String]? = nil) {
        self.id = id
        self.text = text
        self.name = name
        self.timestamp = timestamp
        self.isRead = isRead
        self.seenBy = seenBy
    }
}
// MARK: - ChatUser Model
struct ChatUser: Codable {
    let userId: String
    let role: Int
}

// MARK: - SignalR Received Message Model
struct ReceivedPrivateMessage: Codable {
    let From: String?
    let from: String?
    let Text: String?
    let text: String?
    let TimeStamp: String?
    let timeStamp: String?
    let ChatId: Int?
    let chatId: Int?
    let MessageId: Int? // Add message ID from server
    let messageId: Int?
    
    var name: String {
        return from ?? From ?? "Unknown"
    }
    
    var messageText: String {
        return text ?? Text ?? ""
    }
    
    var id: Int {
        return chatId ?? ChatId ?? 0
    }
    
    var actualMessageId: Int {
        return messageId ?? MessageId ?? abs("\(name)\(messageText)\(timestampString)".hashValue)
    }
    
    var timestampString: String {
        return timeStamp ?? TimeStamp ?? Date().ISO8601Format()
    }
    
    func toMessage() -> Message {
        return Message(
            id: actualMessageId,
            text: messageText,
            name: name,
            timestamp: timestampString,
            isRead: false
        )
    }
}

// MARK: - User Status Model
struct UserStatus {
    let userName: String
    let isOnline: Bool
    let lastSeen: Date?
}

// MARK: - API Response Models
struct GetAllChatsResponse: Codable {
    let id: Int
    let name: String
    let pictureUrl: String
    let lastMessage: LastMessage?
    let unreadCount: Int
    let isOnline: Bool
    let type: Int
    
    struct LastMessage: Codable {
        let text: String
        let time: String
    }
    
    // Convert API response to Chat model
    func toChat() -> Chat {
        let message = lastMessage.map { lastMsg -> Message in
            Message(
                id: 0, // Temporary ID for last message preview
                text: lastMsg.text,
                name: name,
                timestamp: lastMsg.time
            )
        }
        
        return Chat(
            id: id,
            name: name,
            pictureUrl: pictureUrl,
            type: type,
            messages: message.map { [$0] } ?? [],
            users: [],
            unreadCount: unreadCount,
            isOnline: isOnline
        )
    }
}
// MARK: - Chat Models
struct ChatResponse: Codable {
    let chatData: Chat
    let chatStatus: String
}

struct SendMessageRequest: Codable {
    let Message: String
    let chatId: Int
}


extension Chat: Equatable {
    public static func == (lhs: Chat, rhs: Chat) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Chat {
    func containsUser(userId: String) -> Bool {
        return users.contains { $0.userId == userId }
    }
    
    func isPrivateChatWithUser(userId: String) -> Bool {
        // Private chats should have exactly 2 users and contain the target user
        return type == 1 &&
               users.count == 2 &&
               containsUser(userId: userId)
    }
}
