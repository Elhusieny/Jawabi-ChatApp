import Foundation

// MARK: - Authentication Response Models
struct LoginResponse: Codable {
    let token: String?
    let userName: String?
    let email: String?
    let displayName: String?
    let serverUrl: String?
    let userId: String?        // ADD THIS
    let expiration: String?    // ADD THIS (optional)
    // Handle different response structures
    enum CodingKeys: String, CodingKey {
        case token
        case userName
        case email
        case displayName
        case serverUrl = "server_url"
        case userId
        case expiration
    }
    
    // Flexible initializer for different response formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        token = try container.decodeIfPresent(String.self, forKey: .token)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        serverUrl = try container.decodeIfPresent(String.self, forKey: .serverUrl)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)      // ADD THIS
         expiration = try container.decodeIfPresent(String.self, forKey: .expiration) // ADD THIS
    }
}

// MARK: - API User Model (for GetAllUsers)
struct GetAllUsersDM: Codable, Identifiable {
    let id: String
    let name: String
    let pictureUrl: String
    let phoneNumber: String
    
    // MARK: - Update GetAllUsersDM model with FIXED logic
    var fullPictureUrl: String {
           let baseUrl = "http://158.220.90.131:8444"
           
           // If pictureUrl is empty or ends with default.png, use default image
           if pictureUrl.isEmpty || pictureUrl.hasSuffix("default.png") {
               return "\(baseUrl)/uploads/users/default.png"
           }
           
           // If it's already a full URL, return as is
           if pictureUrl.hasPrefix("http://") || pictureUrl.hasPrefix("https://") {
               return pictureUrl
           }
           
           // If it starts with /uploads
           if pictureUrl.hasPrefix("/uploads") {
               return baseUrl + pictureUrl
           }
           
           // If it's just a filename
           return "\(baseUrl)/uploads/users/\(pictureUrl)"
       }
       
       // Helper to check if it's a default image - CORRECT LOGIC
       var isDefaultImage: Bool {
           // Check if it ends with "default.png" (handles both "default.png" and "/uploads/users/default.png")
           return pictureUrl.isEmpty || pictureUrl.hasSuffix("default.png")
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
            let baseUrl = "http://158.220.90.131:8444"
            
            // If empty or ends with default.png, return default
            if pictureUrl.isEmpty || pictureUrl.hasSuffix("default.png") {
                return "\(baseUrl)/uploads/users/default.png"
            }
            
            // If it's already a full URL, return as is
            if pictureUrl.hasPrefix("http://") || pictureUrl.hasPrefix("https://") {
                return pictureUrl
            }
            
            // If it starts with /uploads
            if pictureUrl.hasPrefix("/uploads") {
                return baseUrl + pictureUrl
            }
            
            // Otherwise, assume it's a relative path
            return baseUrl + pictureUrl
        }
        
        // Also add a helper to check if it's a default image
        var isDefaultImage: Bool {
            return pictureUrl.isEmpty || pictureUrl.hasSuffix("default.png")
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
    
    // In Chat.swift - change the init(from decoder:)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        
        // 👇 Use decodeIfPresent with a fallback for null name
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        
        pictureUrl = try container.decodeIfPresent(String.self, forKey: .pictureUrl) ?? ""
        type = try container.decodeIfPresent(Int.self, forKey: .type) ?? 0
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

// MARK: - Message Type Enum (Matching Backend)
enum MessageType: Int, Codable {
    case text = 0
    case image = 1
    case voice = 2
    case file = 3
    case video = 4
}


struct Message: Codable, Identifiable {
    let id: Int
    let displayText: String
    let name: String
    let timestamp: String
    
    // ── New backend fields ──────────────────────────────
    let fileUrl: String?
    let type: MessageType?
    let isFile: Bool?
    let fileName: String?
    let fileSize: Int64?
    let isSafe: Bool?
    var isRead: Bool?
    var seenBy: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, displayText, name, timestamp
        case fileUrl, type, isFile, fileName, fileSize
        case fileExtension = "extension"   // reserved keyword → mapped
        case isSafe, isRead, seenBy
    }
    
    // Stored under a non-keyword property name
    let fileExtension: String?
    
    init(id: Int,             displayText: String, name: String, timestamp: String,
         fileUrl: String? = nil, type: MessageType? = nil,
         isFile: Bool? = nil, fileName: String? = nil,
         fileSize: Int64? = nil, fileExtension: String? = nil,
         isSafe: Bool? = nil,
         isRead: Bool? = nil, seenBy: [String]? = nil) {
        self.id = id
        self.displayText =             displayText
        self.name = name
        self.timestamp = timestamp
        self.fileUrl = fileUrl
        self.type = type
        self.isFile = isFile
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileExtension = fileExtension
        self.isSafe = isSafe
        self.isRead = isRead
        self.seenBy = seenBy
    }
    
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
}
// MARK: - ChatUser Model
struct ChatUser: Codable {
    let userId: String
    let role: Int
}

// MARK: - SignalR Received Message Model - UPDATED with backend fields
struct ReceivedPrivateMessage: Codable {
    let From: String?
    let from: String?
    let Text: String?
    let text: String?
    let TimeStamp: String?
    let timeStamp: String?
    let ChatId: Int?
    let chatId: Int?
    let MessageId: Int?
    let messageId: Int?
    
    // Existing fields
    let isFile: Bool?
    let isSafe: Bool?
    let fileUrl: String?
    
    // ✅ NEW FIELDS from backend DTO
    let fileName: String?
    let fileSize: Int64?
    let `extension`: String?
    let type: String?  // Backend sends Type as string: "0", "1", etc.
    
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
    
    // Convert type string to MessageType enum
    var messageType: MessageType {
        guard let typeString = type, let typeInt = Int(typeString) else {
            return .text
        }
        return MessageType(rawValue: typeInt) ?? .text
    }
    
    func toMessage() -> Message {
        Message(
            id: actualMessageId,
            displayText: messageText,
            name: name,
            timestamp: timestampString,
            fileUrl: fileUrl,
            type: messageType,
            isFile: isFile,
            fileName: fileName,
            fileSize: fileSize,
            fileExtension: `extension`,
            isSafe: isSafe,
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

struct GetAllChatsResponse: Codable {
    let id: Int
    let name: String?           // ← make optional
    let pictureUrl: String?     // ← harden this too
    let lastMessage: LastMessage?
    let unreadCount: Int?
    let isOnline: Bool?
    let type: Int?
    
    struct LastMessage: Codable {
        let text: String?       // ← also harden nested fields
        let time: String?
    }
    
    func toChat() -> Chat {
        let message = lastMessage.flatMap { lastMsg -> Message? in
            guard let text = lastMsg.text, let time = lastMsg.time else { return nil }
            return Message(id: 0,             displayText: text, name: name ?? "Unknown", timestamp: time)
        }
        
        return Chat(
            id: id,
            name: name ?? "Unknown",            // ← fallback here
            pictureUrl: pictureUrl ?? "",
            type: type ?? 1,
            messages: message.map { [$0] } ?? [],
            users: [],
            unreadCount: unreadCount ?? 0,
            isOnline: isOnline ?? false
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


// MARK: - New Models for File Scan and Message Seen Status

struct ScannedFileResult: Codable {
    let isSafe: Bool
    let virusFound: Bool
    let message: String
    let fileUrl: String?
    let originalFileName: String
    
    enum CodingKeys: String, CodingKey {
        case isSafe
        case virusFound
        case message
        case fileUrl
        case originalFileName
    }
}
// MARK: - Updated Models for File Scan and Message Seen Status

struct FileStatusUpdatedData: Codable {
    let messageId: Int
    let fileUrl: String
    let isSafe: Bool
    let fileName: String?
    
    enum CodingKeys: String, CodingKey {
        case messageId
        case fileUrl
        case isSafe
        case fileName
    }
}

// MARK: - Updated MessageWithSeenStatus with new fields
struct MessageWithSeenStatus: Codable, Identifiable {
    let id: Int
    let from: String
    let displayText: String
    let timeStamp: String
    let isRead: Bool
    let isFile: Bool
    let isSafe: Bool
    let fileUrl: String?
    
    // ✅ NEW FIELDS
    let fileName: String?
    let fileSize: Int64?
    let `extension`: String?
    let type: String?
    
    var messageType: MessageType {
        guard let typeString = type, let typeInt = Int(typeString) else {
            return .text
        }
        return MessageType(rawValue: typeInt) ?? .text
    }
    
    func toMessage() -> Message {
        Message(
            id: id,
            displayText: displayText,
            name: from,
            timestamp: timeStamp,
            fileUrl: fileUrl,
            type: messageType,
            isFile: isFile,
            fileName: fileName,
            fileSize: fileSize,
            fileExtension: `extension`,
            isSafe: isSafe,
            isRead: isRead
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case from
        case displayText
        case timeStamp
        case isRead
        case isFile
        case isSafe
        case fileUrl
        case fileName
        case fileSize
        case `extension`
        case type
    }
}
// MARK: - Blocked Message Tracking
struct BlockedMessageInfo {
    let messageId: Int
    let text: String
    let sender: String
    let timestamp: Date
    let reason: String
}

struct ErrorMessage: Codable {
    let message: String
    let chatId: Int?
    
    enum CodingKeys: String, CodingKey {
        case message
        case chatId
    }
}
// In your Chat.swift or in the extension
extension Chat {
    var isCurrentUserAdmin: Bool {
        let currentUserId = UserDefaults.standard.string(forKey: "currentUserId") ?? ""
        print("🔍 Checking admin: Current user ID = \(currentUserId)")
        print("🔍 Users in chat: \(users)")
        
        let isAdmin = users.contains { user in
            user.userId == currentUserId && user.role == 0
        }
        print("🔍 Is admin: \(isAdmin)")
        return isAdmin
    }
}
