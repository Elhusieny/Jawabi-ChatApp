import Foundation
import Combine
class NetworkService {
    static let shared = NetworkService()
    let baseURL = Utilities.baseURL
    
    // Remove the stored token property and always read from UserDefaults
        private var token: String? {
            return UserDefaults.standard.string(forKey: "authToken")
        }
        private init() {}
    func createPrivateChat(with userId: String) -> AnyPublisher<ChatResponse, Error> {
        guard let url = URL(string: "\(baseURL)/api/Chat/PrivateChat") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &urlRequest)
        
        print("💬 Creating private chat with user: \(userId)")
        
        // Try sending the user ID as a raw string
        if let jsonData = "\"\(userId)\"".data(using: .utf8) {
            urlRequest.httpBody = jsonData
            print("📦 Sending raw string: \"\(userId)\"")
        } else {
            return Fail(error: NetworkError.serverError("Failed to create request body")).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                print("📡 Chat Creation Response: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Chat Response: \(responseString)")
                }
                
                if httpResponse.statusCode == 401 {
                    UserDefaults.standard.removeObject(forKey: "authToken")
                   // throw NetworkError.authenticationError
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw NetworkError.serverError("Failed to create chat: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: ChatResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
        // MARK: - Helper method to add authentication headers
        private func addAuthHeaders(to request: inout URLRequest) {
            if let token = token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔐 Adding auth token to request: \(token.prefix(20))...")
            } else {
                print("❌ No auth token available in UserDefaults")
            }
        }
        
        
    // MARK: - Get All Users (with authentication)
        func getAllUsers() -> AnyPublisher<[APIUser], Error> {
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
                            let users = try JSONDecoder().decode([APIUser].self, from: data)
                            print("✅ Successfully decoded \(users.count) users as direct array")
                            return users
                        } catch {
                            throw error
                        }
                    }
                }
                .eraseToAnyPublisher()
        }
//        
//        // MARK: - Create Private Chat
//        func createPrivateChat(with userId: String) -> AnyPublisher<ChatResponse, Error> {
//            guard let url = URL(string: "\(baseURL)/api/Chat/PrivateChat") else {
//                return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
//            }
//            
//            var urlRequest = URLRequest(url: url)
//            urlRequest.httpMethod = "POST"
//            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
//            addAuthHeaders(to: &urlRequest) // Add auth header
//            
//            let requestBody = ["userId": userId]
//            
//            do {
//                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
//            } catch {
//                return Fail(error: error).eraseToAnyPublisher()
//            }
//            
//            return URLSession.shared.dataTaskPublisher(for: urlRequest)
//                .tryMap { data, response in
//                    guard let httpResponse = response as? HTTPURLResponse else {
//                        throw NetworkError.invalidResponse
//                    }
//                    
//                    print("📡 Chat Creation Response: \(httpResponse.statusCode)")
//                    
//                    if let responseString = String(data: data, encoding: .utf8) {
//                        print("📦 Chat Response: \(responseString)")
//                    }
//                    
//                    guard httpResponse.statusCode == 200 else {
//                        throw NetworkError.serverError("Failed to create chat: \(httpResponse.statusCode)")
//                    }
//                    
//                    return data
//                }
//                .decode(type: ChatResponse.self, decoder: JSONDecoder())
//                .eraseToAnyPublisher()
//        }
        
    func sendMessage(_ request: SendMessageRequest) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "\(baseURL)/api/SignalR/SendMessage") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &urlRequest)
        
        print("📤 Sending message: '\(request.Message)' to chat: \(request.chatId)")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            
            // Print the request for debugging
            if let jsonString = String(data: urlRequest.httpBody!, encoding: .utf8) {
                print("📦 Send Message Request: \(jsonString)")
            }
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📡 Send Message Response: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Send Message Response Body: \(responseString)")
                }
                
                // Handle 401 specifically
                if httpResponse.statusCode == 401 {
                    print("🔐 Authentication failed for SendMessage - clearing token")
                    UserDefaults.standard.removeObject(forKey: "authToken")
                    //throw NetworkError.authenticationError
                }
                
                if httpResponse.statusCode == 200 {
                    return "Message sent successfully"
                } else {
                    // Try to get more specific error message
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorResponse["message"] as? String {
                        throw NetworkError.serverError(errorMessage)
                    } else {
                        throw NetworkError.serverError("Failed to send message: \(httpResponse.statusCode)")
                    }
                }
            }
            .eraseToAnyPublisher()
    }
        
        // MARK: - Get Chat
        func getChat(_ chatId: Int) -> AnyPublisher<Chat, Error> {
            guard let url = URL(string: "\(baseURL)/api/Chat/GetChat/\(chatId)") else {
                return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
            }
            
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            addAuthHeaders(to: &urlRequest) // Add auth header
            
            return URLSession.shared.dataTaskPublisher(for: urlRequest)
                .tryMap { data, response in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NetworkError.invalidResponse
                    }
                    
                    print("📡 Get Chat Response: \(httpResponse.statusCode)")
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📦 Chat Data: \(responseString)")
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        throw NetworkError.serverError("Failed to fetch chat: \(httpResponse.statusCode)")
                    }
                    
                    return data
                }
                .decode(type: Chat.self, decoder: JSONDecoder())
                .eraseToAnyPublisher()
        }
    }
    
 extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
