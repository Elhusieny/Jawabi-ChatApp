
import Foundation
import Combine
class GetAllUsersService:AuthHeaderAdding {
    static let shared = GetAllUsersService()
    let baseURL = Utilities.baseURL
    
    // Always read from UserDefaults
    var token: String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    private init() {}
    
    // MARK: - Get All Users (with authentication)
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
                    
                    // If we get a 401, check what the response says
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
                    // Try alternative decoding if the main one fails
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
