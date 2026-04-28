import Foundation

// ✅ Helper to parse JWT token and extract profile picture URL
struct JWTTokenParser {
    
    /// Parse JWT token and extract profile picture URL
    static func getProfilePictureFromToken(_ token: String) -> String? {
        // Split token into parts
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            print("❌ Invalid JWT token format")
            return nil
        }
        
        // Get the payload (middle part)
        let base64Url = parts[1]
        
        // Convert base64url to base64
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let paddingLength = 4 - base64.count % 4
        if paddingLength < 4 {
            base64 += String(repeating: "=", count: paddingLength)
        }
        
        // Decode base64
        guard let data = Data(base64Encoded: base64) else {
            print("❌ Failed to decode JWT token")
            return nil
        }
        
        // Parse JSON
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Look for profile picture claim
                // Backend uses: "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/uri"
                if let picPath = json["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/uri"] as? String {
                    return getWebUrl(picPath)
                }
            }
        } catch {
            print("❌ Failed to parse JWT JSON: \(error)")
        }
        
        return nil
    }
    
    /// Convert local path to web URL (matching backend getWebUrl function)
    private static func getWebUrl(_ localPath: String) -> String {
        if localPath.isEmpty {
            return "https://ui-avatars.com/api/?name=User"
        }
        
        var path = localPath.replacingOccurrences(of: "\\", with: "/")
        
        // Extract path after /uploads/
        if let range = path.range(of: "/uploads/") {
            path = String(path[range.lowerBound...].dropFirst(1))
        } else if let range = path.range(of: "uploads/") {
            path = String(path[range.lowerBound...])
        }
        
        let baseUrl = Utilities.baseURL
        return "\(baseUrl)/\(path)"
    }
    
    /// Get all user info from JWT token
    static func getUserInfoFromToken(_ token: String) -> [String: Any]? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }
        
        let base64Url = parts[1]
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let paddingLength = 4 - base64.count % 4
        if paddingLength < 4 {
            base64 += String(repeating: "=", count: paddingLength)
        }
        
        guard let data = Data(base64Encoded: base64) else { return nil }
        
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            print("❌ Failed to parse JWT: \(error)")
            return nil
        }
    }
}

// ✅ Extension to AuthViewModel to use JWT parser
extension AuthViewModel {
    
    /// Reload profile picture from current token
    func reloadProfilePictureFromToken() {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ No token found")
            return
        }
        
        if let profilePicUrl = JWTTokenParser.getProfilePictureFromToken(token) {
            print("✅ Profile picture from token: \(profilePicUrl)")
            
            // Update userInfo with new profile picture
            if var currentUserInfo = self.userInfo {
                currentUserInfo.profilePicture = profilePicUrl
                self.userInfo = currentUserInfo
            }
        }
    }
}