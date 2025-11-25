
import Foundation
import UIKit
class Utilities {
    static let baseURL = "http://158.220.90.131:8444"
}


// MARK: - Network Errors
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case encodingError(Error)
    case unauthorized
    case serverError(String)
    case unknown
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP Error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError:
            return "Server error"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

// MARK: - Auth Service
class AuthService {
    static let shared = AuthService()
    
    private init() {}
    
    func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    
    func getCurrentUserId() -> String {
        return UserDefaults.standard.string(forKey: "currentUserId") ?? ""
    }
    
    func getCurrentUsername() -> String {
        return UserDefaults.standard.string(forKey: "currentUsername") ?? ""
    }
}
// Add this extension for better date formatting
extension Date {
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}



// For handling image uploads
extension UIImage {
    func toData() -> Data? {
        return self.jpegData(compressionQuality: 0.8)
    }
}
protocol AuthHeaderAdding {
    var token: String? { get }
    func addAuthHeaders(to request: inout URLRequest)
}

extension AuthHeaderAdding {
    func addAuthHeaders(to request: inout URLRequest) {
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔐 Adding auth token to request: \(token.prefix(20))...")
        } else {
            print("❌ No auth token available")
        }
    }
}
extension Data {
   mutating func append(_ string: String) {
       if let data = string.data(using: .utf8) {
           append(data)
       }
   }
}

