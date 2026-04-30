import Foundation
import Combine
import Alamofire

/// Service responsible for handling user account deletion operations
class DeleteAccountService {
    /// Shared singleton instance
    static let shared = DeleteAccountService()
    
    /// Base URL for API endpoints
    private let baseURL = Utilities.baseURL
    
    /// Private initializer for singleton pattern
    private init() {}
    
    // MARK: - Delete Account
    
    /// Deletes the currently authenticated user's account
    /// - Returns: A publisher that emits true if deletion was successful, or an error
    func deleteAccount() -> AnyPublisher<Bool, Error> {
        guard let url = URL(string: "\(baseURL)/api/Chat/DeleteMyAccount") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 Using token for delete account: \(token.prefix(20))...")
        } else {
            print("❌ No auth token found")
        }
        
        print("🗑️ Sending delete account request to: \(url.absoluteString)")
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📡 Delete account response status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Delete account response: \(responseString)")
                }
                
                if httpResponse.statusCode == 401 {
                    print("🔐 Authentication failed - invalid token")
                }
                
                // Handle successful deletion (204 No Content or 200 OK)
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                    print("✅ Account deleted successfully")
                    return true
                } else {
                    throw NetworkError.serverError("Failed to delete account: \(httpResponse.statusCode)")
                }
            }
            .eraseToAnyPublisher()
    }
}
