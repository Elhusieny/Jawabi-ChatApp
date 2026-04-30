import Foundation
import Combine

/// Service responsible for fetching all users from the chat system
class GetAllUsersService: AuthHeaderAdding {
    /// Shared singleton instance
    static let shared = GetAllUsersService()
    
    /// Base URL for API endpoints
    let baseURL = Utilities.baseURL
    
    /// Computed property to retrieve authentication token from UserDefaults
    var token: String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    
    /// Private initializer for singleton pattern
    private init() {}
    
    // MARK: - Get All Users
    
    /// Fetches all users available in the system
    /// - Returns: A publisher that emits an array of GetAllUsersDM or an error
    func getAllUsers() -> AnyPublisher<[GetAllUsersDM], Error> {
        guard let url = URL(string: "\(baseURL)/api/Chat/GetAllUsers") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication header
        addAuthHeaders(to: &urlRequest)
        
        print("🔍 Fetching users from: \(url.absoluteString)")
        
        // Debug token status
        if let token = token {
            print("✅ Token found: \(token.prefix(20))...")
        } else {
            print("❌ No token found in UserDefaults")
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📡 Response Status: \(httpResponse.statusCode)")
                
                // Print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Raw Response: \(responseString)")
                    
                    // Check for authentication issues
                    if httpResponse.statusCode == 401 {
                        print("🔐 Authentication failed. Server response: \(responseString)")
                    }
                }
                
                // Handle 401 Unauthorized specifically
                if httpResponse.statusCode == 401 {
                    // Clear the invalid token
                    UserDefaults.standard.removeObject(forKey: "authToken")
                    //throw NetworkError.authenticationError
                    print("invalid token")
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw NetworkError.serverError("Failed to fetch users: \(httpResponse.statusCode)")
                }
                
                // Try to decode the response
                do {
                    let decoder = JSONDecoder()
                    let usersResponse = try decoder.decode(UsersResponse.self, from: data)
                    print("✅ Successfully decoded \(usersResponse.result.count) users")
                    return usersResponse.result
                } catch {
                    print("❌ Decoding error: \(error)")
                    // Try alternative decoding as direct array if wrapped response fails
                    do {
                        let users = try JSONDecoder().decode([GetAllUsersDM].self, from: data)
                        print("✅ Successfully decoded \(users.count) users as direct array")
                        return users
                    } catch {
                        throw error
                    }
                }
            }
            .eraseToAnyPublisher()
    }
}
