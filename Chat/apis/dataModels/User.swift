import Foundation

// MARK: - Authentication Response Models
struct LoginResponse: Codable {
    let token: String?
    let userName: String?
    let email: String?
    let displayName: String?
    
    // Handle different response structures
    enum CodingKeys: String, CodingKey {
        case token
        case userName
        case email
        case displayName
    }
    
    // Flexible initializer for different response formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        token = try container.decodeIfPresent(String.self, forKey: .token)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
    }
}

// MARK: - API User Model (for GetAllUsers)
struct APIUser: Codable, Identifiable {
    let id: String
    let name: String
    let pictureUrl: String
    
    var fullPictureUrl: String {
        if pictureUrl.hasPrefix("http") {
            return pictureUrl
        } else {
            return "http://184.174.37.115:8444\(pictureUrl)"
        }
    }
}

// MARK: - App User Model (for registration/login)
struct AppUser: Codable, Identifiable {
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
    let result: [APIUser]
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
}

// MARK: - Chat Models
struct ChatResponse: Codable {
    let chatData: Chat
    let chatStatus: String
}

struct Chat: Codable, Identifiable {
    let id: Int
    let name: String
    let pictureUrl: String
    let type: Int
    let messages: [Message]
    let users: [ChatUser]
    
    var fullPictureUrl: String {
        if pictureUrl.hasPrefix("http") {
            return pictureUrl
        } else {
            return "http://184.174.37.115:8444\(pictureUrl)"
        }
    }
}

struct Message: Codable, Identifiable {
    let id: Int
    let text: String
    let name: String
    let timestamp: String
    
    var date: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter.date(from: timestamp) ?? Date()
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct ChatUser: Codable {
    let userId: String
    let role: Int
}

struct SendMessageRequest: Codable {
    let Message: String
    let chatId: Int
}
// Add this to your NetworkService.swift file or create a separate file for errors


