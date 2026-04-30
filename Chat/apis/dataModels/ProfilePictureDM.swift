import Foundation

// MARK: - Profile Picture Data Model
struct ProfilePictureDM: Codable {
    let token: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case token
        case message
    }
}

// MARK: - Profile Picture Upload Response (FIXED)
struct ProfilePictureResponse: Codable {
    // Direct response from your JavaScript code
    let token: String?
    let message: String?
    
    // Helper computed property
    var isSuccess: Bool {
        return message?.lowercased().contains("success") == true ||
               message?.lowercased().contains("updated") == true
    }
    
    enum CodingKeys: String, CodingKey {
        case token = "token"
        case message = "message"
    }
}

// MARK: - User Profile Model (keep as is)
struct UserProfile: Codable {
    let displayName: String
    let profilePictureUrl: String
    let email: String
    let phoneNumber: String
    let serverUrl: String?
    var fullPictureUrl: String {
        let baseUrl = "http://158.220.90.131:8444"
        
        if profilePictureUrl.isEmpty || profilePictureUrl.hasSuffix("default.png") {
            return "\(baseUrl)/uploads/users/default.png"
        }
        
        if profilePictureUrl.hasPrefix("http://") || profilePictureUrl.hasPrefix("https://") {
            return profilePictureUrl
        }
        
        if profilePictureUrl.hasPrefix("/uploads") {
            return baseUrl + profilePictureUrl
        }
        
        return "\(baseUrl)/uploads/users/\(profilePictureUrl)"
    }
    
    var isDefaultImage: Bool {
        return profilePictureUrl.isEmpty || profilePictureUrl.hasSuffix("default.png")
    }
    
    enum CodingKeys: String, CodingKey {
        case displayName
        case email
        case phoneNumber
        case profilePictureUrl
        case serverUrl
    }
}
